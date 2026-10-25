# shellcheck shell=bash
# convert-to-subvolume PATH...: turns an existing directory into a nested btrfs subvolume IN PLACE,
# so btrbk's @home snapshots stop at it. A reflink copy (no extra space, no data rewritten), a
# check by path and size, then a swap. The old copy is KEPT next to it: deleting it is the caller's
# call, after the app was tested. Why: docs/notes/boot-and-storage/disk-hygiene.md
set -euo pipefail

die() {
  echo "convert-to-subvolume: $*" >&2
  exit 1
}

[ "$#" -gt 0 ] || die "usage: convert-to-subvolume PATH... (absolute, or relative to \$HOME)"

for arg in "$@"; do
  case "$arg" in
  /*) p="${arg%/}" ;;
  *) p="$HOME/${arg%/}" ;;
  esac
  new="$p.subvol-new"
  old="$p.pre-subvol"

  [ -d "$p" ] && [ ! -L "$p" ] || die "$p is not a directory"
  [ "$(stat -f -c %T "$p")" = btrfs ] || die "$p is not on btrfs"
  if [ "$(stat -c %i "$p")" = 256 ]; then
    echo "$p is already a subvolume, nothing to do"
    continue
  fi
  [ ! -e "$new" ] && [ ! -e "$old" ] || die "a leftover $new or $old exists; inspect it first"

  # BUSY means refuse: a VM writing its image or a game patching during the copy would make the
  # two trees disagree, and an overlay mounted under it would be copied as if it were data.
  if findmnt -rn -o TARGET | grep -qF -- "$p/"; then
    die "something is mounted under $p; stop it first"
  fi
  busy="$(find /proc/[0-9]*/cwd /proc/[0-9]*/fd -maxdepth 1 \( -lname "$p" -o -lname "$p/*" \) 2>/dev/null | head -n 1 || true)"
  [ -z "$busy" ] || die "a process is using $p ($busy); close it first"

  btrfs subvolume create "$new" >/dev/null
  # A failure from here on removes the half-made copy; the original is never touched before the swap.
  trap 'rm -rf -- "$new"' ERR

  # The directories FIRST, carrying +C (nodatacow) where the original has it. cp does not copy that
  # flag, and btrfs refuses to clone between a nodatacow file and a normal one. MEASURED on
  # 24/10/2026: every file of a VM image directory failed with EINVAL until this was in place.
  # A file only inherits +C from its directory when it is created, hence before the copy.
  while IFS= read -r -d '' d; do
    mkdir -p "$new/$d"
    if lsattr -d "$p/$d" 2>/dev/null | cut -d' ' -f1 | grep -q C; then
      chattr +C "$new/$d"
    fi
  done < <(cd "$p" && find . -type d -print0)

  # --reflink=always fails loudly instead of silently doubling the space with a real copy.
  cp -a --reflink=always "$p/." "$new/"

  # The same check as every move on the games disk: path and size per file, never a total.
  list() { (cd "$1" && find . \( -type f -o -type l \) -printf '%s\t%P\n' | LC_ALL=C sort); }
  if ! cmp -s <(list "$p") <(list "$new"); then
    die "the copy does not match; $new is left for inspection and $p is untouched"
  fi
  trap - ERR

  mv "$p" "$old"
  mv "$new" "$p"
  echo "$p is now a subvolume ($(list "$p" | wc -l) files checked)"
  echo "  after testing the app, remove the old copy: rm -rf '$old'"
done

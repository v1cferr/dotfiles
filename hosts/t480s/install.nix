# `t480s-install`: the ONE destructive command of this host. It asks for the LUKS passphrase and
# each account's password, then hands the machine to nixos-anywhere: docs/guides/t480s-install.md
{
  lib,
  writeShellApplication,
  coreutils,
  mkpasswd,
  nixos-anywhere,
  # { "<user>" = "<the root-only file that holds the hash>"; }, read from the host's own config.
  passwordFiles,
  # Where disko reads the LUKS passphrase at format time, read from the host's own config.
  luksKeyFile,
}:

writeShellApplication {
  name = "t480s-install";
  runtimeInputs = [
    coreutils
    mkpasswd
    nixos-anywhere
  ];
  text = ''
    target="''${1:?usage: t480s-install <user@address of the machine booted into the installer>}"

    # Typed twice and never echoed; the prompts go to stderr so the answer alone is the output.
    ask() {
      local first second
      while :; do
        read -rsp "$1: " first
        echo >&2
        read -rsp "$1, again: " second
        echo >&2
        if [ -n "$first" ] && [ "$first" = "$second" ]; then
          printf '%s' "$first"
          return
        fi
        echo "empty, or the two differ; once more" >&2
      done
    }

    echo "This ERASES the whole disk of $target and installs t480s on it." >&2
    read -rp "Type t480s to go on: " confirm
    [ "$confirm" = t480s ] || exit 1

    work="$(mktemp -d)"
    trap 'rm -rf "$work"' EXIT

    # No trailing newline: what is typed at boot has none either.
    ask "The disk's LUKS passphrase" > "$work/luks"

    # The tree nixos-anywhere copies onto the new root. The modes are the target's, so the parents
    # stay 0755 and only the leaf is private.
    ${lib.concatStrings (
      lib.mapAttrsToList (user: file: ''
        install -d -m 0755 "$work/root$(dirname "$(dirname ${lib.escapeShellArg file})")"
        install -d -m 0700 "$work/root$(dirname ${lib.escapeShellArg file})"
        ask "The login password of ${user}" | mkpasswd -m yescrypt -s > "$work/root"${lib.escapeShellArg file}
        chmod 0600 "$work/root"${lib.escapeShellArg file}
      '') passwordFiles
    )}
    nixos-anywhere \
      --flake "''${FLAKE:-.}#t480s" \
      --target-host "$target" \
      --disk-encryption-keys ${lib.escapeShellArg luksKeyFile} "$work/luks" \
      --extra-files "$work/root"
  '';
}

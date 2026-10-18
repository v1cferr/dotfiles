# `bios-aspm`: sets the ASPM options ASUS hides in THIS board's BIOS 2803 (3 bytes of setup variables).
# The IFR evidence, the offsets, the exception and the way back: docs/guides/bios-ex-b560m-v5.md
{ pkgs, ... }:

let
  inherit (pkgs)
    coreutils
    diffutils
    e2fsprogs
    gnugrep
    gnused
    pciutils
    systemd
    writeShellApplication
    ;

  bios-aspm = writeShellApplication {
    name = "bios-aspm";
    runtimeInputs = [
      coreutils
      diffutils
      e2fsprogs
      gnugrep
      gnused
      pciutils
      systemd
    ];
    text = ''
      # Read from the official BIOS 2803 image's IFR on 18/10/2026. Valid for that version ONLY.
      board=EX-B560M-V5
      bios=2803
      efi=/sys/firmware/efi/efivars
      setup=Setup-ec87d643-eba4-4bb5-a1e5-3f3e36b20da9
      sa=SaSetup-72c5e28c-7783-43a1-8767-fad73fccafa4
      backups=/var/backup/bios-aspm

      # name|variable|size with the 4-byte header|offset|wanted|allowed values
      fields=(
        "PCI Express Native Power Management|$setup|2698|0x51|1|0 1"
        "Native ASPM (OS controlled)|$setup|2698|0x52|1|0 1 2"
        "CPU PCIe Root Port 1 (PEG, the x16 slot) ASPM|$sa|993|0x35D|2|0 1 2 3"
      )

      die() { echo "bios-aspm: $*" >&2; exit 1; }
      byte() { od -An -tu1 -j "$(($2 + 4))" -N1 "$1" | tr -d ' '; }

      # Every precondition, re-checked before any write: wrong board, BIOS or layout = no write.
      check() {
        [ "$(cat /sys/class/dmi/id/board_name)" = "$board" ] || die "not an $board"
        [ "$(cat /sys/class/dmi/id/bios_version)" = "$bios" ] || die "BIOS $(cat /sys/class/dmi/id/bios_version), the offsets are for $bios only"
        for f in "''${fields[@]}"; do
          IFS='|' read -r name var size off _ allowed <<<"$f"
          [ -f "$efi/$var" ] || die "$var is missing"
          [ "$(stat -c %s "$efi/$var")" = "$size" ] || die "$var is not $size bytes: a different layout"
          [ "$(od -An -tx1 -N4 "$efi/$var" | tr -d ' ')" = 07000000 ] || die "$var has unexpected attributes"
          v="$(byte "$efi/$var" "$off")"
          grep -qw -- "$v" <<<"$allowed" || die "$name reads $v, not one of: $allowed"
        done
      }

      status() {
        for f in "''${fields[@]}"; do
          IFS='|' read -r name var _ off want _ <<<"$f"
          v="$(byte "$efi/$var" "$off")"
          printf '%-48s %s (wanted %s)%s\n' "$name" "$v" "$want" "$([ "$v" = "$want" ] && echo '  ok')"
        done
        echo
        # No `grep -q`: an early exit SIGPIPEs journalctl, and pipefail turns the match into a miss.
        if journalctl -k -b | grep 'FADT.*ASPM' >/dev/null; then
          echo "kernel: the FADT still says ASPM is unsupported (the BIOS controls it)"
        else
          echo "kernel: no FADT ASPM line (the OS controls ASPM)"
        fi
        if [ "$(id -u)" = 0 ]; then
          lspci -vv -s 00:01.0 | grep -E 'LnkCap:|LnkCtl:' | sed 's/^/00:01.0 /'
          lspci -vv -s 01:00.0 | grep -E 'LnkCtl:' | sed 's/^/01:00.0 /'
        fi
      }

      # One write() of header plus data per variable, which is what efivarfs requires.
      put() {
        chattr -i "$efi/$1" 2>/dev/null || true
        dd if="$2" of="$efi/$1" bs="$(stat -c %s "$2")" count=1 status=none
        chattr +i "$efi/$1" 2>/dev/null || true
      }

      # `cat`, never `cp`: coreutils' cp seeks, and efivarfs answers "Illegal seek". Size-checked.
      grab() {
        cat "$efi/$1" >"$2/$1"
        [ "$(stat -c %s "$2/$1")" = "$(stat -c %s "$efi/$1")" ] || die "a short read of $1"
      }

      rollback() {
        put "$setup" "$1/$setup" || true
        put "$sa" "$1/$sa" || true
      }

      apply() {
        [ "$(id -u)" = 0 ] || die "run it with sudo"
        check
        todo=0
        for f in "''${fields[@]}"; do
          IFS='|' read -r _ var _ off want _ <<<"$f"
          [ "$(byte "$efi/$var" "$off")" = "$want" ] || todo=1
        done
        [ "$todo" = 1 ] || { echo "bios-aspm: already applied, nothing to write"; exit 0; }

        dir="$backups/$(date +%Y%m%d-%H%M%S)"
        install -d -m 0700 "$dir"
        grab "$setup" "$dir"
        grab "$sa" "$dir"
        (cd "$dir" && sha256sum ./* >SHA256SUMS)
        echo "bios-aspm: backup in $dir"
        status
        echo
        read -r -p "Write these 3 bytes into the BIOS setup variables? Type 'yes': " ok
        [ "$ok" = yes ] || die "aborted, nothing written"

        work="$(mktemp -d)"
        trap 'rm -rf "$work"' EXIT
        grab "$setup" "$work"
        grab "$sa" "$work"
        for f in "''${fields[@]}"; do
          IFS='|' read -r _ var _ off want _ <<<"$f"
          printf '%b' "\\x$(printf %02x "$want")" | dd of="$work/$var" bs=1 seek="$((off + 4))" conv=notrunc status=none
        done
        for var in "$setup" "$sa"; do
          put "$var" "$work/$var" || { rollback "$dir"; die "the write of $var failed; the backup was written back"; }
          cmp -s "$efi/$var" "$work/$var" || { rollback "$dir"; die "$var did not read back as written; the backup was written back"; }
        done
        echo
        status
        echo
        echo "bios-aspm: written. Reboot, then run 'sudo bios-aspm status'."
        echo "  Way back from Linux: sudo bios-aspm restore $dir"
        echo "  Way back if it does not POST: Clear CMOS (the CLRTC jumper), which restores the defaults."
      }

      restore() {
        [ "$(id -u)" = 0 ] || die "run it with sudo"
        dir="''${1:?usage: bios-aspm restore <backup dir>}"
        (cd "$dir" && sha256sum -c --quiet SHA256SUMS) || die "the backup in $dir does not match its checksums"
        check
        for var in "$setup" "$sa"; do
          put "$var" "$dir/$var"
          cmp -s "$efi/$var" "$dir/$var" || die "$var did not read back as the backup"
        done
        echo "bios-aspm: restored from $dir. Reboot to take effect."
        status
      }

      case "''${1:-status}" in
        status) status ;;
        apply) apply ;;
        restore) restore "''${2:-}" ;;
        *) die "usage: bios-aspm [status|apply|restore <backup dir>]" ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ bios-aspm ];
}

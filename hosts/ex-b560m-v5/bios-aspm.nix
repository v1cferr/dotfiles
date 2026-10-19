# `bios-aspm`: sets the ASPM options ASUS hides in THIS board's BIOS 2803 (3 bytes of setup variables).
# The IFR evidence, the offsets, the exception and the way back: docs/guides/bios-ex-b560m-v5.md
{
  config,
  lib,
  pkgs,
  ...
}:

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
      # The dead man's switch: "<boot_id> <backup dir>", armed by apply, cleared by confirm.
      pending=/var/lib/bios-aspm/pending
      # Present while the bytes were last seen applied: their silent loss (F5, Clear CMOS) is news.
      enabled=/var/lib/bios-aspm/enabled

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
        if [ -f "$pending" ]; then
          echo "guard: ARMED, restores $(cut -d' ' -f2 "$pending") 10 min into a later boot unless 'sudo bios-aspm confirm'"
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
        arm "$dir"
        echo "bios-aspm: written. Reboot, then run 'sudo bios-aspm status' and 'sudo bios-aspm confirm'."
        echo "  Way back from Linux: sudo bios-aspm restore $dir"
        echo "  Way back if it does not POST: Clear CMOS (the CLRTC jumper), which restores the defaults."
      }

      arm() {
        [ "$(id -u)" = 0 ] || die "run it with sudo"
        (cd "$1" && sha256sum -c --quiet SHA256SUMS) || die "the backup in $1 does not match its checksums"
        install -d -m 0700 "$(dirname "$pending")"
        echo "$(cat /proc/sys/kernel/random/boot_id) $(realpath "$1")" >"$pending"
        echo "bios-aspm: guard armed; a later boot restores $1 after 10 min unless you run 'sudo bios-aspm confirm'"
      }

      confirm() {
        [ "$(id -u)" = 0 ] || die "run it with sudo"
        rm -f "$pending"
        echo "bios-aspm: confirmed, the guard is disarmed"
      }

      # Run by the timer: acts only on a boot OTHER than the one that armed it.
      guard() {
        [ -f "$pending" ] || exit 0
        read -r armed dir <"$pending"
        [ "$armed" != "$(cat /proc/sys/kernel/random/boot_id)" ] || exit 0
        echo "bios-aspm: not confirmed 10 min into this boot, restoring $dir"
        restore "$dir"
        rm -f "$pending"
      }

      applied() {
        for f in "''${fields[@]}"; do
          IFS='|' read -r _ var _ off want _ <<<"$f"
          [ "$(byte "$efi/$var" "$off")" = "$want" ] || return 1
        done
      }

      # The newest backup whose checksums hold: the state right before the last apply.
      newest_backup() {
        found=""
        for d in "$backups"/*/; do
          [ -d "$d" ] && (cd "$d" && sha256sum -c --quiet SHA256SUMS >/dev/null 2>&1) && found="''${d%/}"
        done
        [ -n "$found" ] && echo "$found"
      }

      notify() {
        echo "$1: $2"
        [ -z "''${ALERT:-}" ] || "$ALERT" bios-aspm dialog-warning "$1" "$2" || true
      }

      # A failure on the card's path: write the original bytes back (they take effect next boot).
      fatal() {
        if applied && dir="$(newest_backup)" && (restore "$dir" >/dev/null); then
          rm -f "$enabled"
          notify "bios-aspm: PCIe/GPU failure, ASPM rolled back" "$1 | The original BIOS bytes are back ($dir); reboot to run without ASPM."
        else
          notify "bios-aspm: PCIe/GPU failure" "$1 | Nothing rolled back automatically; check 'sudo bios-aspm status'."
        fi
      }

      # The kernel log since boot, event by event. The card's path is the root port, its bridges,
      # the GPU and its HDMI audio; nothing else on the bus is judged here.
      watch() {
        install -d -m 0700 "$(dirname "$enabled")"
        if applied; then
          touch "$enabled"
        elif [ -f "$enabled" ]; then
          rm -f "$enabled"
          notify "bios-aspm: ASPM is off again" "The BIOS variables lost the ASPM bytes (F5, Clear CMOS or a BIOS update). Run 'sudo bios-aspm status', then 'apply' if the BIOS is still $bios."
        fi
        gpu='0000:(00:01\.0|01:00\.0|02:0[12]\.0|03:00\.0|04:00\.0)'
        bad='(AER: Uncorrected|severity=(Uncorrectable|Fatal)|Link Down|link down)'
        last=-600
        corrected=0
        while IFS= read -r line; do
          if { [[ $line =~ $gpu ]] && [[ $line =~ $bad ]]; } || [[ $line =~ xe\ 0000:03:00\.0.*wedged ]]; then
            fatal "$line"
          elif [[ $line =~ $gpu ]] && [[ $line =~ (AER: Corrected|severity=Corrected) ]]; then
            corrected=$((corrected + 1))
            if ((SECONDS - last >= 600)); then
              notify "bios-aspm: corrected PCIe errors on the GPU link" "$corrected since the last alert, the latest: $line. The hardware recovered; a steady stream means ASPM is not stable here."
              last=$SECONDS
              corrected=0
            fi
          elif [[ $line =~ xe\ 0000:03:00\.0.*(reset started|Timedout job) ]]; then
            notify "bios-aspm: the GPU reset itself" "$line | One reset can be a game; repeated ones with ASPM on: 'sudo bios-aspm restore $(newest_backup || echo '<dir>')'."
          fi
        done < <(if [ "''${1:-}" = --stdin ]; then cat; else journalctl -k -b -f -o cat; fi)
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
        arm) arm "''${2:?usage: bios-aspm arm <backup dir>}" ;;
        confirm) confirm ;;
        guard) guard ;;
        watch) watch "''${2:-}" ;;
        restore) restore "''${2:-}" ;;
        *) die "usage: bios-aspm [status|apply|confirm|arm <dir>|restore <dir>|watch]" ;;
      esac
    '';
  };
in
{
  environment.systemPackages = [ bios-aspm ];

  # Ten minutes into each boot: an unconfirmed change from an EARLIER boot is written back, so a
  # boot with no screen and no SSH heals with a wait and a power cycle.
  systemd.services.bios-aspm-guard = {
    description = "Restores the ASPM bytes unless the change was confirmed";
    onFailure = [ "bios-aspm-guard-alert.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe bios-aspm} guard";
    };
  };
  systemd.timers.bios-aspm-guard = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnBootSec = "10min";
  };
  # Live: rolls the bytes back on a hard PCIe/GPU failure, warns on soft ones, and notices a reset BIOS.
  systemd.services.bios-aspm-watch = {
    description = "Watches the kernel log for PCIe and GPU failures while ASPM is on";
    wantedBy = [ "multi-user.target" ];
    environment.ALERT = lib.getExe config.my.alert;
    serviceConfig = {
      ExecStart = "${lib.getExe bios-aspm} watch";
      Restart = "always";
      RestartSec = 10;
    };
  };
  systemd.services.bios-aspm-guard-alert = {
    description = "Alarm: the ASPM guard failed";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''${lib.getExe config.my.alert} bios-aspm dialog-warning "bios-aspm: the guard failed" "See 'journalctl -u bios-aspm-guard'. Restore by hand: sudo bios-aspm restore <backup dir>."'';
    };
  };
}

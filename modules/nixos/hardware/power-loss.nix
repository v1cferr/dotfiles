# POWER LOSS: after a boot that followed an unclean shutdown, one alarm says what recovered.
# The marker design, the report and the recovery checklist: docs/notes/hardware/power-loss.md
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Rule 19: everything this module reaches for, named once.
  inherit (pkgs)
    coreutils
    gawk
    gnugrep
    smartmontools
    systemd
    writeShellApplication
    ;

  dir = "/var/lib/power-loss";

  # Boot: a marker still here means the last boot never reached its clean stop. Flag it, re-arm.
  arm = writeShellApplication {
    name = "power-loss-arm";
    runtimeInputs = [ coreutils ];
    text = ''
      if [ -e ${dir}/running ]; then cp ${dir}/running ${dir}/pending; fi
      cat /proc/sys/kernel/random/boot_id >${dir}/running
    '';
  };

  # Five minutes into the boot: every recovery has run (a container Postgres took 2 min on 24/11)
  # and the autologin session can get the bubble.
  report = writeShellApplication {
    name = "power-loss-report";
    runtimeInputs = [
      coreutils
      gawk
      gnugrep
      smartmontools
      systemd
    ];
    text = ''
      # The NVMe's own count, kept every boot so a report shows the jump of THIS incident.
      unsafe=0
      for d in /dev/nvme[0-9]; do
        [ -e "$d" ] || continue
        n="$(smartctl -A "$d" | awk -F: '/Unsafe Shutdowns/ { gsub(/[ ,]/, "", $2); print $2 }' || true)"
        unsafe=$((unsafe + ''${n:-0}))
      done
      prev="$(cat ${dir}/unsafe-shutdowns 2>/dev/null || echo "$unsafe")"
      echo "$unsafe" >${dir}/unsafe-shutdowns

      [ -e ${dir}/pending ] || exit 0

      k() { journalctl -b 0 -k -o cat --no-pager | grep -E "$1" || true; }
      j() { journalctl -b 0 -o short-iso --no-hostname --no-pager -g "$1" 2>/dev/null || true; }
      last="$(journalctl -b -1 -n 1 -o short-iso --no-hostname --no-pager | awk 'NR == 1 { print $1 }')"
      replay="$(k 'tree-log replay')"
      btrfs="$(k 'BTRFS (error|warning|critical)' | grep -v swapfile || true)"
      ntfs="$(k 'ntfs3\(.*\): .*(Correct|dirty|error)')"
      esp="$(j 'Dirty bit is set')"
      pg="$(j 'automatic recovery in progress')"
      failed="$(systemctl --failed --no-legend --plain | awk '{ print $1 }')"
      count() { if [ -z "$1" ]; then echo 0; else grep -c . <<<"$1"; fi; }

      summary="Power was lost after $last.
      btrfs: $([ -n "$replay" ] && echo "tree-log replayed" || echo "clean mount"), $(count "$btrfs") errors or warnings
      ESP: $([ -n "$esp" ] && echo "fsck cleared the dirty bit" || echo "clean")
      ntfs3: $(count "$ntfs") corrections$([ -n "$ntfs" ] && echo ", run chkdsk from Windows")
      Postgres: $(count "$pg") crash recoveries
      NVMe unsafe shutdowns: $unsafe (+$((unsafe - prev)))
      Failed units: $(echo "''${failed:-none}" | tr '\n' ' ')"

      {
        echo "$summary"
        printf '\n--- previous boot: %s\n' "$(cat ${dir}/pending)"
        printf '\n--- btrfs\n%s\n%s\n' "$replay" "$btrfs"
        printf '\n--- ntfs3\n%s\n' "$ntfs"
        printf '\n--- ESP fsck\n%s\n' "$esp"
        printf '\n--- Postgres\n%s\n' "$pg"
      } >${dir}/last-report

      ${lib.getExe config.my.alert} power-loss dialog-warning "Recovered from a power loss" \
        "$summary
      Full report: ${dir}/last-report"
      rm -f ${dir}/pending
    '';
  };
in
{
  # ExecStop is the clean-shutdown proof: it only runs when systemd stops the unit on purpose.
  systemd.services.power-loss-marker = {
    description = "Marker that tells a clean shutdown from a power loss";
    wantedBy = [ "multi-user.target" ];
    after = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "power-loss";
      ExecStart = lib.getExe arm;
      ExecStop = "${coreutils}/bin/rm -f ${dir}/running";
    };
  };

  systemd.services.power-loss-report = {
    description = "Report what recovered after a power loss";
    after = [ "power-loss-marker.service" ];
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "power-loss";
      ExecStart = lib.getExe report;
    };
  };

  systemd.timers.power-loss-report = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnBootSec = "5min";
  };
}

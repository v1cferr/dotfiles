# POWER LOG: every minute, what each MEASURABLE part drew (CPU, GPU) plus its context, as a CSV.
# What is measured, what is not, the wall-meter slot and `power-report`: docs/notes/hardware/power.md
{ pkgs, ... }:

let
  inherit (pkgs)
    coreutils
    gawk
    gnugrep
    power-profiles-daemon
    writeShellApplication
    ;

  dir = "/var/lib/power-log";

  # Cumulative counters read once a minute: the average of each interval is exact, whatever the
  # sampling rate, so a minute costs nothing and misses no burst.
  sample = writeShellApplication {
    name = "power-log-sample";
    runtimeInputs = [
      coreutils
      gawk
      gnugrep
      power-profiles-daemon
    ];
    text = ''
      shopt -s nullglob
      dir=${dir}
      state=$dir/last
      install -d -m 0755 "$dir"

      rd() { if [ -r "$1" ]; then cat "$1"; else echo 0; fi; }
      hw() { for h in /sys/class/hwmon/hwmon*; do [ "$(cat "$h/name")" = "$1" ] && { echo "$h"; return; }; done; }
      # The temp channel whose label is $2, in milli-degrees.
      temp() { for l in "$1"/temp*_label; do [ "$(cat "$l")" = "$2" ] && { cat "''${l%_label}_input"; return; }; done; echo 0; }

      xe="$(hw xe)"
      core="$(hw coretemp)"
      nvme="$(hw nvme)"
      rapl=/sys/class/powercap/intel-rapl:0
      gt=(/sys/class/drm/card*/device/tile0/gt0/gtidle/idle_residency_ms)
      media=(/sys/class/drm/card*/device/tile0/gt1/gtidle/idle_residency_ms)

      boot="$(cat /proc/sys/kernel/random/boot_id)"
      now="$(date +%s%N)"
      pkg="$(rd $rapl/energy_uj)"
      cores="$(rd $rapl/intel-rapl:0:0/energy_uj)"
      range="$(rd $rapl/max_energy_range_uj)"
      card="$(rd "$xe/energy1_input")"
      chip="$(rd "$xe/energy2_input")"
      rc6="$(rd "''${gt[0]:-/nonexistent}")"
      rc6m="$(rd "''${media[0]:-/nonexistent}")"
      read -r _ u n s idle io irq sirq steal _ </proc/stat
      busy=$((u + n + s + irq + sirq + steal))
      tot=$((busy + idle + io))

      cur="$boot $now $pkg $cores $card $chip $rc6 $rc6m $busy $tot"
      prev="$(cat "$state" 2>/dev/null || true)"
      echo "$cur" >"$state"
      # A first sample, a new boot or a gap over 10 min (powered off) has no interval to report.
      read -r pboot pnow ppkg pcores pcard pchip prc6 prc6m pbusy ptot <<<"''${prev:-x 0 0 0 0 0 0 0 0 0}"
      [ "$pboot" = "$boot" ] || exit 0
      dt=$((now - pnow))
      if [ "$dt" -le 0 ] || [ "$dt" -gt 600000000000 ]; then exit 0; fi

      file="$dir/$(date +%Y-%m).csv"
      [ -f "$file" ] || echo "time,interval_s,profile,cpu_package_w,cpu_cores_w,gpu_board_w,gpu_chip_w,measured_w,wall_w,gpu_render_idle_pct,gpu_media_idle_pct,cpu_busy_pct,cpu_c,gpu_c,nvme_c" >"$file"
      profile="$(powerprofilesctl get 2>/dev/null || echo unknown)"
      awk -v dt="$dt" -v pkg="$((pkg - ppkg))" -v cores="$((cores - pcores))" -v range="$range" \
        -v card="$((card - pcard))" -v chip="$((chip - pchip))" -v rc6="$((rc6 - prc6))" -v rc6m="$((rc6m - prc6m))" \
        -v busy="$((busy - pbusy))" -v tot="$((tot - ptot))" -v profile="$profile" -v t="$(date -Is)" \
        -v cc="$(temp "$core" 'Package id 0')" -v gc="$(temp "$xe" pkg)" -v nc="$(rd "$nvme/temp1_input")" '
        function w(uj) { if (uj < 0) uj += range; return uj / (dt / 1000) }
        BEGIN {
          s = dt / 1e9; cpu = w(pkg); gpu = (card < 0 ? 0 : card) / (dt / 1000)
          printf "%s,%.0f,%s,%.2f,%.2f,%.2f,%.2f,%.2f,,%.1f,%.1f,%.1f,%.0f,%.0f,%.0f\n", t, s, profile,
            cpu, w(cores), gpu, (chip < 0 ? 0 : chip) / (dt / 1000), cpu + gpu,
            100 * rc6 / (s * 1000), 100 * rc6m / (s * 1000), (tot > 0 ? 100 * busy / tot : 0),
            cc / 1000, gc / 1000, nc / 1000
        }' >>"$file"
    '';
  };

  # Averages over a window, overall, per profile and per hour of the day.
  report = writeShellApplication {
    name = "power-report";
    runtimeInputs = [
      coreutils
      gawk
    ];
    text = ''
      hours="''${1:-24}"
      since="$(date -d "-$hours hours" -Is)"
      files=(${dir}/*.csv)
      [ -e "''${files[0]}" ] || { echo "power-report: no samples yet in ${dir}"; exit 1; }
      echo "power-report: the last $hours h (since $since). MEASURED = CPU package + GPU board; the rest of the PC (board, RAM, SSD, fans, PSU loss, monitors) has no sensor here."
      awk -F, -v since="$since" '
        FNR == 1 { for (i = 1; i <= NF; i++) c[$i] = i; next }
        $1 < since { next }
        {
          n++; m = $c["measured_w"]; tw += $c["interval_s"]
          for (k in cols) sum[k] += $c[k]
          p = $c["profile"]; pn[p]++; pt[p] += $c["interval_s"]; pm[p] += m; pg[p] += $c["gpu_board_w"]; pc[p] += $c["cpu_package_w"]; pr[p] += $c["gpu_render_idle_pct"]
          h = substr($1, 12, 2); hn[h]++; ht[h] += $c["interval_s"]; hm[h] += m; hr[h] += $c["gpu_render_idle_pct"]
          if (min == "" || m < min) min = m; if (m > max) max = m
        }
        BEGIN { split("cpu_package_w cpu_cores_w gpu_board_w gpu_chip_w measured_w gpu_render_idle_pct cpu_busy_pct", a, " "); for (i in a) cols[a[i]] }
        END {
          if (!n) { print "no samples in the window"; exit }
          printf "\n%d samples, %.1f h covered\n", n, tw / 3600
          printf "  measured   avg %6.1f W   min %6.1f   max %6.1f   ~%.2f kWh in the window\n", sum["measured_w"] / n, min, max, sum["measured_w"] / n * tw / 3600 / 1000
          printf "  cpu pkg    avg %6.1f W   (cores %.1f)\n", sum["cpu_package_w"] / n, sum["cpu_cores_w"] / n
          printf "  gpu board  avg %6.1f W   (chip %.1f), render idle %.0f%%\n", sum["gpu_board_w"] / n, sum["gpu_chip_w"] / n, sum["gpu_render_idle_pct"] / n
          printf "  cpu busy   avg %6.1f %%\n", sum["cpu_busy_pct"] / n
          print "\nby profile:"
          for (p in pn) printf "  %-12s %5.0f min  measured %6.1f W  (cpu %5.1f, gpu %5.1f, render idle %3.0f%%)\n", p, pt[p] / 60, pm[p] / pn[p], pc[p] / pn[p], pg[p] / pn[p], pr[p] / pn[p]
          print "\nby hour of day (measured W, render idle %):"
          for (i = 0; i < 24; i++) { h = sprintf("%02d", i); if (hn[h]) printf "  %s h  %6.1f W  %3.0f%%  (%.0f min)\n", h, hm[h] / hn[h], hr[h] / hn[h], ht[h] / 60 }
        }' "''${files[@]}"
    '';
  };
in
{
  environment.systemPackages = [ report ];

  systemd.services.power-log = {
    description = "Samples the measurable power draw (CPU, GPU) into /var/lib/power-log";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${sample}/bin/power-log-sample";
      Nice = 19;
    };
  };
  systemd.timers.power-log = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
      AccuracySec = "1s";
    };
  };
}

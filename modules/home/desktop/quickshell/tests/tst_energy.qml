// EnergyMath: power-log's CSV into the energy document (status, split, holes, Eco-idle baseline).
import QtQuick
import QtTest
import "../data"

TestCase {
    name: "Energy"

    EnergyMath {
        id: m
    }
    readonly property string head: "time,interval_s,profile,cpu_package_w,cpu_cores_w,gpu_board_w,gpu_chip_w,measured_w,wall_w,gpu_render_idle_pct,gpu_media_idle_pct,cpu_busy_pct,cpu_c,gpu_c,nvme_c"
    function row(t, profile, cpu, gpu, idle, busy) {
        const iso = new Date(t * 1000).toISOString().slice(0, 19) + "Z";
        return [iso, 60, profile, cpu, 1, gpu, 1, cpu + gpu, "", idle, 90, busy, 40, 40, 40].join(",");
    }
    readonly property real now: 1792600000

    function test_empty_is_missing() {
        compare(m.energy("", now, 1800).status, "missing");
    }
    function test_last_row_and_holes() {
        const lines = [head];
        for (let i = 29; i >= 0; i--)
            if (i !== 5)
                lines.push(row(now - i * 60 - 30, "balanced", 40, 45, 40, 5));
        const d = m.energy(lines.join("\n"), now, 1800);
        compare(d.status, "ok");
        compare(d.measured_w, 85);
        compare(d.cpu_w, 40);
        compare(d.gpu_w, 45);
        compare(d.history.length, 30);
        compare(d.history.filter(v => v === null).length, 1, "a missing minute is a hole, not a zero");
        compare(d.baseline, null, "no Eco-idle samples, no baseline");
    }
    function test_stale_after_three_minutes() {
        compare(m.energy([head, row(now - 400, "balanced", 1, 1, 1, 1)].join("\n"), now, 1800).status, "stale");
    }
    function test_repeated_header_where_months_meet() {
        const d = m.energy([head, row(now - 120, "balanced", 1, 1, 1, 1), head, row(now - 60, "balanced", 2, 2, 1, 1)].join("\n"), now, 1800);
        compare(d.measured_w, 4);
    }
    function test_baseline_only_from_eco_idle() {
        const lines = [head];
        for (let i = 0; i < 40; i++)
            lines.push(row(now - 3600 - i * 60, "power-saver", 20, 33, 90, 3));
        for (let i = 0; i < 40; i++)
            lines.push(row(now - 9000 - i * 60, "power-saver", 30, 42, 10, 3)); // a stream: GPU busy
        const d = m.energy(lines.join("\n"), now, 1800);
        compare(d.baseline.median_w, 53);
        compare(d.baseline.samples, 40);
    }
}

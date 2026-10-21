// SystemMath: /proc/stat, meminfo, rc6 and the per-app ranking (names only, never command lines).
import QtQuick
import QtTest
import "../data"

TestCase {
    name: "System"

    SystemMath {
        id: m
    }

    function test_cpu() {
        const a = m.cpuTicks("cpu  100 0 100 800 0 0 0 0 0 0\ncpu0 1 2 3");
        compare(a, [1000, 800]);
        const b = m.cpuTicks("cpu  150 0 150 900 0 0 0 0 0 0");
        compare(m.cpuPct(a, b), 50);
        verify(isNaN(m.cpuPct(null, b)));
    }
    function test_mem_uses_available() {
        const r = m.mem("MemTotal: 1000 kB\nMemFree: 100 kB\nMemAvailable: 600 kB\n");
        compare(r.used, 400 * 1024, "page cache is not used memory");
    }
    function test_render_idle() {
        compare(m.renderIdle(1000, 1500, 1), 50);
        compare(m.renderIdle(0, 5000, 1), 100, "clamped");
    }
    function test_group_names() {
        compare(m.groupOf("/user.slice/user-1000.slice/user@1000.service/app.slice/app-Hyprland-code-1234.scope", "code"), "code");
        compare(m.groupOf("/user.slice/user-1000.slice/user@1000.service/app.slice/wireplumber.service", "wireplumber"), "wireplumber");
        compare(m.groupOf("", ".quickshell-wra"), "quickshell", "a Nix wrapper's comm is unwrapped");
        compare(m.groupOf("/user.slice/user-1000.slice/session-2.scope", "Hyprland"), "Hyprland");
    }
    function test_rank() {
        const stat = (pid, comm, ticks, rss) => pid + " (" + comm + ") S 1 1 1 0 -1 0 0 0 0 0 " + ticks + " 0 0 0 20 0 1 0 777 0 " + rss;
        const cg = (pid, unit) => "/proc/" + pid + "/cgroup:0::/user.slice/" + unit;
        const t0 = m.procs([stat(10, "a b", 100, 10), stat(11, "child", 0, 5)].join("\n") + "\n---\n" + [cg(10, "app-foo.scope"), cg(11, "app-foo.scope")].join("\n"));
        const t1 = m.procs([stat(10, "a b", 300, 10), stat(11, "child", 100, 5)].join("\n") + "\n---\n" + [cg(10, "app-foo.scope"), cg(11, "app-foo.scope")].join("\n"));
        const r = m.rank(t0, t1, 1, 3);
        compare(r.cpu, [{ name: "foo", value: 300 }], "children summed into their app, % of one core");
        compare(r.mem[0].value, 15 * m.page);
    }
}

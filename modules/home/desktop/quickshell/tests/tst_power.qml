// PowerMath: the session actions' state machine (confirm, one run at a time, errors, handoff).
import QtQuick
import QtTest
import "../power"

TestCase {
    name: "Power"

    PowerMath {
        id: m
    }
    function go(s, type, extra) {
        return m.step(s, Object.assign({
            type: type
        }, extra || {}));
    }

    function test_six_actions_keep_their_commands() {
        compare(m.actions.length, 6);
        compare(m.action("reboot").cmd.join(" "), "systemctl reboot");
        compare(m.action("poweroff").cmd.join(" "), "systemctl poweroff");
        compare(m.action("suspend").cmd.join(" "), "systemctl suspend");
        compare(m.actions.filter(a => a.confirm).map(a => a.key).join(","), "logout,reboot,poweroff");
    }
    function test_a_destructive_action_asks_first() {
        const s = go(m.idle, "request", {
            key: "poweroff"
        });
        compare(s.phase, "confirm");
        compare(s.run, false, "nothing runs before the confirmation");
        const t = go(s, "confirm");
        compare(t.phase, "busy");
        compare(t.run, true);
    }
    function test_a_safe_action_runs_at_once() {
        const s = go(m.idle, "request", {
            key: "suspend"
        });
        compare(s.phase, "busy");
        compare(s.run, true);
        compare(go(s, "exited", {
            code: 0
        }).phase, "idle");
    }
    function test_no_second_run_while_busy() {
        const busy = go(go(m.idle, "request", {
            key: "reboot"
        }), "confirm");
        const again = go(busy, "confirm");
        compare(again.run, false, "a double confirm never runs twice");
        compare(go(busy, "request", {
            key: "poweroff"
        }).run, false);
        compare(go(busy, "request", {
            key: "poweroff"
        }).key, "reboot", "the running action keeps the dialog");
        compare(go(busy, "cancel").phase, "busy", "a running command cannot be cancelled into a lie");
    }
    function test_cancel_and_escape() {
        const s = go(m.idle, "request", {
            key: "logout"
        });
        compare(go(s, "cancel").phase, "idle");
        compare(go(m.idle, "confirm").run, false, "a stray confirm with nothing asked does nothing");
    }
    function test_success_of_an_ending_action_hands_off() {
        const busy = go(go(m.idle, "request", {
            key: "poweroff"
        }), "confirm");
        const h = go(busy, "exited", {
            code: 0
        });
        compare(h.phase, "handoff");
        compare(go(h, "cancel").phase, "handoff", "the OS has it now");
        compare(go(h, "stalled").phase, "error", "but not forever");
    }
    function test_failure_shows_the_command_words() {
        const busy = go(go(m.idle, "request", {
            key: "reboot"
        }), "confirm");
        const e = go(busy, "exited", {
            code: 1,
            stderr: "Call to Reboot failed: Operation inhibited by \"steam\"\n"
        });
        compare(e.phase, "error");
        verify(e.error.indexOf("inhibited") >= 0, e.error);
        compare(go(busy, "exited", {
            code: 3,
            stderr: ""
        }).error, "Reboot failed (exit 3).");
        compare(go(e, "cancel").phase, "idle");
    }
    function test_unknown_key_is_ignored() {
        compare(go(m.idle, "request", {
            key: "hibernate"
        }).phase, "idle");
    }
}

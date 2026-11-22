pragma Singleton
// The session actions' state: Lock, Log out, Suspend, Reboot, Shut down. One command at a
// time, its exit code read, and the three that end the session ask first: a second click on the same one is the yes.
// IPC: `qs ipc call power ask <key>`. The rules: docs/notes/desktop/nixos-center.md
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/power"

Singleton {
    id: root

    PowerMath {
        id: math
    }
    readonly property var actions: math.actions
    property var state: math.idle
    readonly property var current: math.action(root.state.key)

    // TEST ONLY, for a nested shell: "0" or "1" turns every command into `exit` with that code.
    readonly property string dryRun: Quickshell.env("QS_POWER_DRYRUN") || ""

    // A question or a failure needs the Center: it opens itself when this fires and it was closed.
    signal attention

    function send(ev) {
        const prev = root.state.phase;
        const next = math.step(root.state, ev);
        root.state = next;
        if (next.phase !== prev && (next.phase === "confirm" || next.phase === "error"))
            root.attention();
        if (next.run) {
            const a = math.action(next.key);
            proc.command = root.dryRun !== "" ? ["sh", "-c", "sleep 0.4; exit " + Number(root.dryRun)] : a.cmd;
            proc.running = true;
        }
        stall.running = next.phase === "handoff";
    }
    // A second click on what asks is the yes. Not the second half of a double click, though, and
    // not a click that comes long after: the question lapses by itself.
    readonly property int armGap: 400
    readonly property int armLife: 4000
    property real armedAt: 0
    readonly property bool armed: root.state.phase === "confirm"
    // Which one asks: a question moved to another action starts its own time.
    readonly property string armedKey: root.armed ? root.state.key : ""
    onArmedKeyChanged: {
        lapse.stop();
        if (root.armedKey !== "") {
            root.armedAt = Date.now();
            lapse.start();
        }
    }
    Timer {
        id: lapse
        interval: root.armLife
        onTriggered: root.cancel()
    }
    function request(key) {
        if (root.armed && key === root.state.key && Date.now() - root.armedAt < root.armGap)
            return;
        root.send({
            type: "request",
            key: key
        });
    }
    function confirm() {
        root.send({
            type: "confirm"
        });
    }
    function cancel() {
        root.send({
            type: "cancel"
        });
    }

    Process {
        id: proc
        stderr: StdioCollector {
            id: err
        }
        // The stream can finish after the exit, so the text is read on the next turn of the loop.
        onExited: code => Qt.callLater(() => root.send({
                    type: "exited",
                    code: code,
                    stderr: err.text
                }))
    }

    // A queued poweroff can still be held by a delay inhibitor: say so instead of waiting forever.
    Timer {
        id: stall
        interval: 90000
        onTriggered: root.send({
            type: "stalled"
        })
    }

    IpcHandler {
        target: "power"
        function ask(key: string): void {
            root.request(key);
        }
        function cancel(): void {
            root.cancel();
        }
    }
}

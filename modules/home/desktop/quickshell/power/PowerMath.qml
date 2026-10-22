// The session actions and their state machine, as pure functions: no Quickshell imports, so
// qmltestrunner can test them. Power.qml runs it. docs/notes/desktop/nixos-center.md
import QtQml

QtObject {
    // The six actions, commands unchanged from the old footer. `confirm` asks first; `ends` means
    // success hands the screen to the OS, so there is nothing left to report back.
    readonly property var actions: [
        {
            key: "lock",
            icon: "󰌾",
            label: "Lock",
            // The lock's UNIT first, then the LockedHint: `loginctl lock-session` alone only EMITS the signal.
            cmd: ["sh", "-c", "systemctl --user start lockscreen.service; loginctl lock-session"]
        },
        {
            key: "darken",
            icon: "󰖔",
            label: "Darken",
            cmd: ["hyprctl", "hyprsunset", "gamma", "0"] // gamma 0 through hyprsunset, NEVER dpms; input restores it
        },
        {
            key: "logout",
            icon: "󰗽",
            label: "Log out",
            cmd: ["sh", "-c", "loginctl terminate-user \"$USER\""], // LightDM launches a bare Hyprland (no uwsm)
            confirm: true,
            ends: true,
            title: "Log out?",
            body: "Every app in this session is closed. Unsaved work is lost.",
            verb: "Log out",
            going: "Logging out"
        },
        {
            key: "suspend",
            icon: "󰒲",
            label: "Suspend",
            cmd: ["systemctl", "suspend"]
        },
        {
            key: "reboot",
            icon: "󰜉",
            label: "Reboot",
            cmd: ["systemctl", "reboot"],
            confirm: true,
            ends: true,
            title: "Restart the computer?",
            body: "Every app is closed and the machine restarts. Unsaved work is lost.",
            verb: "Restart",
            going: "Restarting"
        },
        {
            key: "poweroff",
            icon: "󰐥",
            label: "Shut down",
            cmd: ["systemctl", "poweroff"],
            confirm: true,
            ends: true,
            title: "Shut down the computer?",
            body: "Every app is closed and the machine powers off. Unsaved work is lost.",
            verb: "Shut down",
            going: "Shutting down"
        }
    ]

    function action(key) {
        return actions.find(a => a.key === key) || null;
    }

    readonly property var idle: ({
            phase: "idle",
            key: "",
            error: ""
        })

    // One event in, the next state out. phase: idle | confirm | busy | handoff | error. `run` tells
    // the caller to start the command NOW, and it is true exactly once per accepted request.
    function step(s, ev) {
        const a = action(ev.key !== undefined ? ev.key : s.key);
        const st = (phase, extra) => Object.assign({
                phase: phase,
                key: a ? a.key : "",
                error: "",
                run: false
            }, extra || {});
        switch (ev.type) {
        case "request":
            if (!a || s.phase === "busy" || s.phase === "handoff")
                return Object.assign({}, s, {
                    run: false
                }); // one request at a time: a double click never runs twice
            return a.confirm ? st("confirm") : st("busy", {
                run: true
            });
        case "confirm":
            return s.phase === "confirm" ? st("busy", {
                run: true
            }) : Object.assign({}, s, {
                run: false
            });
        case "cancel":
            return s.phase === "confirm" || s.phase === "error" ? Object.assign({}, idle, {
                run: false
            }) : Object.assign({}, s, {
                run: false
            });
        case "exited":
            if (s.phase !== "busy")
                return Object.assign({}, s, {
                    run: false
                });
            if (ev.code === 0)
                return a && a.ends ? st("handoff") : Object.assign({}, idle, {
                    run: false
                });
            return st("error", {
                error: errorText(a, ev.code, ev.stderr)
            });
        case "stalled":
            return s.phase === "handoff" ? st("error", {
                error: "The system accepted the request but has not gone down. See `systemctl list-jobs`."
            }) : Object.assign({}, s, {
                run: false
            });
        }
        return Object.assign({}, s, {
            run: false
        });
    }

    // The command's own words when it said something (logind names the inhibitor), else the code.
    function errorText(a, code, stderr) {
        const said = (stderr || "").trim().split("\n").filter(l => l.trim() !== "").pop();
        const what = a ? a.label : "The action";
        return said ? what + " failed: " + said : what + " failed (exit " + code + ").";
    }
}

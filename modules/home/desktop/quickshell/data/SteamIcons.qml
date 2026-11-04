pragma Singleton
// Icons for Steam games, whose window class says nothing ("hl", "steam_app_466560"): Steam starts
// every game with SteamAppId in its environment and installs steam_icon_<id> into the icon theme.
// A pid is read once, and only for a window the .desktop lookup could not resolve. docs/notes/desktop/bar.md
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: steam

    property var appOf: ({}) // pid -> Steam app id, "" when the process is not a Steam game
    property var queued: ({})

    function icon(id) {
        return id && Quickshell.hasThemeIcon("steam_icon_" + id) ? Quickshell.iconPath("steam_icon_" + id) : "";
    }
    function path(name, pid) {
        const m = /^steam_app_(\d+)$/.exec("" + name);
        if (m)
            return steam.icon(m[1]);
        if (!(pid > 0))
            return "";
        if (steam.appOf[pid] === undefined) {
            steam.queued[pid] = true;
            Qt.callLater(steam.read);
            return "";
        }
        return steam.icon(steam.appOf[pid]);
    }
    function read() {
        const pids = Object.keys(steam.queued);
        if (reader.running || pids.length === 0)
            return;
        steam.queued = {};
        reader.command = ["sh", "-c", "for p; do printf '%s\\t' \"$p\"; tr '\\0' '\\n' < /proc/\"$p\"/environ 2>/dev/null | sed -n 's/^SteamAppId=//p' | head -n 1; echo; done", "_"].concat(pids);
        reader.running = true;
    }

    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                const next = Object.assign({}, steam.appOf);
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length === 2 && f[0] !== "")
                        next[f[0]] = f[1].trim();
                }
                steam.appOf = next;
            }
        }
        onExited: Qt.callLater(steam.read) // pids that arrived while it ran
    }
}

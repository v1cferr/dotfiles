pragma Singleton
// Icons for Wine apps, which have no .desktop entry: Bottles keeps one per program in
// <bottle>/icons/<Program>.png. A window's class is its .exe in lowercase ("hearthstone.exe"), so it
// is matched by the program's name, then by the executable bottle.yml lists for it. docs/notes/desktop/bar.md
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: wine

    // normalized key -> absolute path of the icon
    property var icons: ({})
    property double readAt: 0
    // Game executables whose name is not the program's (the launcher spawns them): key -> program key
    readonly property var aliases: ({
            "wow": "worldofwarcraft"
        })

    // "Battle.net.exe", "Battle.net", "Overwatch Launcher.exe" -> "battlenet", "battlenet", "overwatch"
    function key(s) {
        return ("" + s).toLowerCase().replace(/\.exe$/, "").replace(/ launcher$/, "").replace(/[^a-z0-9]/g, "");
    }
    function path(name) {
        const raw = wine.key(name);
        const k = wine.aliases[raw] || raw;
        const p = wine.icons[k];
        if (p)
            return "file://" + p;
        // An .exe nobody knew yet (a program added to a bottle): read the bottles again, at most once a minute.
        if (/\.exe$/i.test(name) && Date.now() - wine.readAt > 60000)
            Qt.callLater(wine.refresh);
        return "";
    }
    function refresh() {
        if (reader.running)
            return;
        wine.readAt = Date.now();
        reader.running = true;
    }

    Process {
        id: reader
        // One line per icon, then one per program (its bottle, executable and name); keys come before
        // `name` in bottle.yml's sorted program blocks.
        command: ["sh", "-c", "for b in \"$HOME\"/.local/share/bottles/bottles/*/; do " + "for i in \"$b\"icons/*.png; do [ -e \"$i\" ] && printf 'icon\\t%s\\n' \"$i\"; done; " + "[ -f \"$b\"bottle.yml ] && awk -v d=\"$b\" '/^        executable:/ { sub(/^ *executable: */, \"\"); exe = $0 } " + "/^        name:/ { sub(/^ *name: */, \"\"); print \"prog\\t\" d \"\\t\" exe \"\\t\" $0 }' \"$b\"bottle.yml; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                const progs = [];
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f[0] === "icon" && f.length === 2)
                        map[wine.key(f[1].replace(/^.*\//, "").replace(/\.png$/, ""))] = f[1];
                    else if (f[0] === "prog" && f.length === 4)
                        progs.push(f);
                }
                // By executable only where the name found nothing: Hearthstone's launcher is Battle.net.exe,
                // which must not take Battle.net's own icon.
                for (const f of progs) {
                    const icon = f[1] + "icons/" + f[3].replace(/^["']|["']$/g, "") + ".png";
                    const k = wine.key(f[2].replace(/^["']|["']$/g, ""));
                    if (!map[k] && Object.values(map).indexOf(icon) >= 0)
                        map[k] = icon;
                }
                wine.icons = map;
            }
        }
    }

    Component.onCompleted: wine.refresh()
}

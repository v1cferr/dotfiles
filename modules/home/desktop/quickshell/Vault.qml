pragma Singleton
// The app vault's prompt state: which hidden apps the password card is asking for. The hiding and
// the grace clock live in hypr/lua/vault.lua; this side only asks and, on success, calls back
// `vault.release(app)` there. IPC: `qs ipc call vault ask <app> | hidden | cancel | lock`.
// The window is vault/VaultPrompt.qml. docs/notes/desktop/vault.md
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var apps: [] // the apps the open card unlocks, in the order they asked
    readonly property bool active: root.apps.length > 0

    readonly property var names: ({
            discord: "Discord",
            zapfast: "WhatsApp",
            telegram: "Telegram",
            chatgpt: "ChatGPT",
            obsidian: "Obsidian",
            zen: "Zen",
            librewolf: "LibreWolf"
        })
    readonly property var icons: ({
            discord: "forum",
            zapfast: "chat",
            telegram: "send",
            chatgpt: "smart_toy",
            obsidian: "description",
            zen: "public",
            librewolf: "public"
        })

    // The names go into a Lua string, so only the vault.lua keys' shape gets through.
    function ask(list) {
        const add = list.filter(a => /^[a-z]+$/.test(a) && root.apps.indexOf(a) < 0);
        if (add.length)
            root.apps = root.apps.concat(add);
    }
    function cancel() {
        root.apps = [];
    }
    function release() {
        for (const a of root.apps)
            Quickshell.execDetached(["hyprctl", "eval", `vault.release("${a}")`]);
        root.apps = [];
    }

    // SUPER+SHIFT+V: ask for everything vault.lua holds right now.
    Process {
        id: hiddenReader
        command: ["hyprctl", "repl", 'return "[" .. vault.hidden() .. "]"']
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/\[(.*)\]/);
                if (m && m[1] !== "")
                    root.ask(m[1].split(" "));
            }
        }
    }

    IpcHandler {
        target: "vault"
        function ask(app: string): void {
            root.ask([app]);
        }
        function hidden(): void {
            hiddenReader.running = true;
        }
        function cancel(): void {
            root.cancel();
        }
        function lock(): void {
            root.cancel();
            Quickshell.execDetached(["hyprctl", "eval", "vault.lock_all()"]);
        }
    }
}

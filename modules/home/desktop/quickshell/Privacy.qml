pragma Singleton
// What is being CAPTURED right now: the microphone, the screen, or the desktop's sound by a
// stream. It only watches; Island.qml shows it. docs/notes/desktop/island.md#capture
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    // ── Sound: every stream that records. Pipewire says which, and from where, once bound ──
    readonly property var inputs: Pipewire.nodes ? Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioInStream) : []
    PwObjectTracker {
        objects: root.inputs
    }
    // Not a person listening: the shell's own wave, a meter drawing a level, a filter's own link.
    readonly property var quiet: /^(cava|pavucontrol|pwvucontrol|easyeffects|effect_)/i
    function who(n) {
        const p = n.properties || {};
        return p["application.name"] || n.nickname || n.name || "";
    }
    function heard(n) {
        const p = n.properties || {};
        return n.ready && !root.quiet.test(n.name || "") && !root.quiet.test(p["application.name"] || "") && p["node.link-group"] === undefined && (p["media.name"] || "").indexOf("Peak detect") < 0;
    }
    // A stream recording an OUTPUT hears the desktop, not the room: that is a stream going out.
    function ofSink(n) {
        return (n.properties || {})["stream.capture.sink"] === "true";
    }
    readonly property var mics: root.inputs.filter(n => root.heard(n) && !root.ofSink(n))
    readonly property var casts: root.inputs.filter(n => root.heard(n) && root.ofSink(n) && /sunshine/i.test(root.who(n)))
    readonly property string micBy: root.mics.length > 0 ? (root.who(root.mics[0]) || "An app") : ""
    readonly property string streamBy: root.casts.length > 0 ? root.who(root.casts[0]) : ""

    // ── The screen: the compositor says when a client starts and stops reading it ──
    property bool screen: false
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "screencast")
                root.screen = event.data.split(",")[0] === "1";
        }
    }
}

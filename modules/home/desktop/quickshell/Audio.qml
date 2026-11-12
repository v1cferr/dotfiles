pragma Singleton
// The ONE owner of the default sink and source: the bar, the OSD and every panel read and set the
// volume here, so two trackers can never disagree. docs/notes/desktop/quickshell.md#audio-and-media
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    // A node's audio is only valid while something binds it.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => !!n)
    }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: (root.sink && root.sink.audio) ? root.sink.audio.volume : 0
    readonly property bool muted: (root.sink && root.sink.audio) ? root.sink.audio.muted : false
    readonly property bool micMuted: (root.source && root.source.audio) ? root.source.audio.muted : false

    readonly property real micVolume: (root.source && root.source.audio) ? root.source.audio.volume : 0

    // ===== The spectrum, for the island's wave =====
    // cava runs only while something asks (`wave`): a child process that reads what is heard and
    // prints 24 levels a frame, bass first, already smoothed and scaled to what plays. It replaced
    // Quickshell's own peak meter, which cost the shell four to six times as much.
    property bool waveIsland: false
    property bool wavePanel: false
    readonly property bool wave: root.waveIsland || root.wavePanel
    property var bands: [] // 0 to 1 each; empty while cava is not running (or not installed)
    // It outlives a pause in the asking by a few seconds: a volume key or a notification takes the
    // capsule for a moment, and starting cava again each time would cost more than letting it run.
    property bool cavaOn: false
    onWaveChanged: {
        if (root.wave) {
            linger.stop();
            root.cavaOn = true;
        } else {
            linger.restart();
        }
    }
    Timer {
        id: linger
        interval: 8000
        onTriggered: {
            root.cavaOn = false;
            root.bands = [];
        }
    }
    Process {
        running: root.cavaOn
        command: ["cava", "-p", Quickshell.shellPath("media/cava.ini")]
        // A shell started from a terminal inherits libraries built on a newer glibc than cava's.
        environment: ({
                LD_LIBRARY_PATH: null
            })
        stdout: SplitParser {
            onRead: line => {
                const out = [];
                for (const part of line.split(" "))
                    if (part !== "")
                        out.push(Math.min(1, parseInt(part) / 1000));
                root.bands = out;
            }
        }
    }

    // ===== The volume of what plays =====
    // The media panel is open: it wants the player's own stream, when one answers to its name or
    // is the only one playing; else the volume is the output's.
    property bool panelOpen: false
    readonly property var playing: (root.panelOpen && Pipewire.nodes) ? Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream) : []
    PwObjectTracker {
        objects: root.playing
    }
    readonly property var playerStream: {
        const who = ((Media.player && Media.player.identity) || "").toLowerCase();
        for (const n of root.playing) {
            const name = ((n.properties && n.properties["application.name"]) || n.name || "").toLowerCase();
            if (who !== "" && name !== "" && (who.indexOf(name) >= 0 || name.indexOf(who) >= 0))
                return n;
        }
        return root.playing.length === 1 ? root.playing[0] : null;
    }
    readonly property var mediaNode: root.playerStream || root.sink || null
    readonly property bool mediaIsPlayer: !!root.playerStream
    readonly property real mediaVolume: (root.mediaNode && root.mediaNode.audio) ? root.mediaNode.audio.volume : 0
    readonly property bool mediaMuted: (root.mediaNode && root.mediaNode.audio) ? root.mediaNode.audio.muted : false
    function setMediaVolume(v) {
        if (root.mediaNode && root.mediaNode.audio)
            root.mediaNode.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMediaMute() {
        if (root.mediaNode && root.mediaNode.audio)
            root.mediaNode.audio.muted = !root.mediaNode.audio.muted;
    }

    function setVolume(v) {
        if (root.sink && root.sink.audio)
            root.sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function setMicVolume(v) {
        if (root.source && root.source.audio)
            root.source.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMic() {
        if (root.source && root.source.audio)
            root.source.audio.muted = !root.source.audio.muted;
    }
    function changeVolume(delta) {
        if (root.sink && root.sink.audio)
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + delta));
    }
    function toggleMute() {
        if (root.sink && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
    }
}

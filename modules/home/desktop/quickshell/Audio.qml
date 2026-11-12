pragma Singleton
// The ONE owner of the default sink and source: the bar, the OSD and every panel read and set the
// volume here, so two trackers can never disagree. docs/notes/desktop/quickshell.md#audio-and-media
import Quickshell
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

    // ===== The level, for the island's wave =====
    // Captured only while something asks (`wave`): the player's own stream when one answers to its
    // name or is the only one playing, so a notification's sound does not move it; else the output.
    // Only streams that PLAY count: the meter's own capture is a stream too, and would feed itself.
    property bool waveIsland: false
    property bool wavePanel: false
    readonly property bool wave: root.waveIsland || root.wavePanel
    // The media panel is open: it wants the player's stream for its volume, playing or not.
    property bool panelOpen: false
    readonly property var playing: ((root.wave || root.panelOpen) && Pipewire.nodes) ? Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioOutStream) : []
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
    readonly property var waveNode: root.playerStream || root.sink || null
    // The volume of what plays: the player's own stream when it is known, else the output's.
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
    PwNodePeakMonitor {
        id: meter
        node: root.waveNode
        enabled: root.wave && !!root.waveNode
    }
    // Read when wanted, never bound: the meter reports some 185 times a second.
    function level() {
        return meter.enabled ? (meter.peak || 0) : 0;
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

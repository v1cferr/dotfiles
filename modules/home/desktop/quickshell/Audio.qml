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

    function changeVolume(delta) {
        if (root.sink && root.sink.audio)
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + delta));
    }
    function toggleMute() {
        if (root.sink && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
    }
}

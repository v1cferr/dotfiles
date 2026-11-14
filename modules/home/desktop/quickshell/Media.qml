pragma Singleton
// The ONE choice of media player for the shell: the one that most recently started playing (rules in
// media/MediaMath.qml). Every media surface reads it. docs/notes/desktop/quickshell.md#audio-and-media
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import QtQml.Models
import QtQuick
import "root:/media"

Singleton {
    id: root

    MediaMath {
        id: math
    }
    readonly property var players: (Mpris.players && Mpris.players.values) ? Mpris.players.values.filter(p => !!p) : []
    // When each player last STARTED playing, by D-Bus name; written only by the watchers below.
    property var seen: ({})
    function started(p) {
        if (p && p.isPlaying)
            root.seen = math.stamp(root.seen, p.dbusName || "", Date.now());
    }
    Instantiator {
        model: root.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() {
                root.started(modelData);
            }
        }
        // One already playing when it appears (or when the shell starts) counts as a start.
        onObjectAdded: (i, o) => root.started(o.modelData)
        onObjectRemoved: root.seen = math.prune(root.seen, root.players.map(p => p.dbusName || ""))
    }

    readonly property var player: {
        const key = math.pick(root.players.map(p => ({
                        key: p.dbusName || "",
                        playing: p.isPlaying
                    })), root.seen);
        return root.players.find(p => (p.dbusName || "") === key) || null;
    }
    readonly property bool hasPlayer: !!root.player
    readonly property bool playing: !!(root.player && root.player.isPlaying)
    // A browser's players say more than the track: YouTube names an artist's channel "X - Topic",
    // and many put the artist in the title too ("X - Song"). Each is said once, for every reader.
    readonly property string rawTitle: (root.player && root.player.trackTitle) ? root.player.trackTitle : ""
    readonly property string title: root.once(root.rawTitle, root.artist)
    readonly property string artist: {
        if (!root.player || !root.player.trackArtists)
            return "";
        const a = root.player.trackArtists;
        return (Array.isArray(a) ? a.join(", ") : ("" + a)).replace(/ - Topic$/, "");
    }
    function once(title, artist) {
        return (artist !== "" && title.toLowerCase().startsWith(artist.toLowerCase() + " - ")) ? title.slice(artist.length + 3) : title;
    }
    // The window what plays lives in: the player's app showing that very title, else any window of
    // that app. Looked for when asked, never bound: every window's title would feed it.
    function window() {
        if (!root.player)
            return null;
        const tokens = [root.player.desktopEntry || "", root.source].map(t => t.toLowerCase()).filter(t => t !== "");
        const mine = ToplevelManager.toplevels.values.filter(w => {
            const id = (w.appId || "").toLowerCase();
            return id !== "" && tokens.some(t => id === t || id.indexOf(t) >= 0 || t.indexOf(id) >= 0);
        });
        const exact = root.rawTitle.length > 3 ? mine.find(w => (w.title || "").indexOf(root.rawTitle) >= 0) : undefined;
        return exact || (mine.length ? mine[0] : null);
    }
    readonly property bool canReveal: !!root.player
    // Go to it: the window when there is one, else whatever the player does when asked to raise.
    function reveal() {
        const w = root.window();
        if (w)
            w.activate();
        else if (root.player && root.player.canRaise)
            root.player.raise();
    }
    // Who plays it, as the player names itself.
    readonly property string source: (root.player && root.player.identity) ? root.player.identity : ""
    readonly property string album: (root.player && root.player.trackAlbum) ? root.player.trackAlbum : ""
    readonly property string artUrl: (root.player && root.player.trackArtUrl) ? root.player.trackArtUrl : ""
    readonly property real length: (root.player && root.player.length) ? root.player.length : 0
    // "Artist - Title", the one line a compact surface shows.
    readonly property string line: !root.hasPlayer ? "" : (root.artist ? root.artist + " - " + root.title : root.title)
}

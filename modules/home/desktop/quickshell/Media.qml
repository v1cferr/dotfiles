pragma Singleton
// The ONE choice of media player for the shell: Spotifast when it is up, else whichever is playing,
// else the first. The bar and the media panel both read it. docs/notes/desktop/quickshell.md#audio-and-media
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import QtQuick

Singleton {
    id: root

    readonly property var player: {
        const m = Mpris.players;
        const list = (m && m.values) ? m.values : [];
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && (p.identity === "Spotifast" || (p.dbusName || "").toLowerCase().indexOf("spotifast") >= 0))
                return p;
        }
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].isPlaying)
                return list[i];
        return list.length ? list[0] : null;
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

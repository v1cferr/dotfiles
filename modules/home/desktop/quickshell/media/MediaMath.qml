// The shell's choice of media player, as pure functions: no Quickshell imports, so qmltestrunner can
// test it. Media.qml runs it. The policy: docs/notes/desktop/quickshell.md#audio-and-media
import QtQml

QtObject {
    // [{ key, playing }] (key = D-Bus name) and { key: ms of its last START }: the newest start among
    // those playing, else the newest at all (a paused track stays shown), else the first key.
    function pick(players, seen) {
        if (!players || players.length === 0)
            return "";
        const at = p => (seen && seen[p.key]) || 0;
        // A tie (never seen) goes by key, so the order players reached the bus never decides.
        const order = (a, b) => (at(b) - at(a)) || (a.key < b.key ? -1 : (a.key > b.key ? 1 : 0));
        const playing = players.filter(p => p.playing).sort(order);
        return (playing.length ? playing : players.slice().sort(order))[0].key;
    }
    // Only a START moves the clock: a pause, a seek or a track change never does, so nothing flickers.
    function stamp(seen, key, now) {
        const s = Object.assign({}, seen);
        s[key] = now;
        return s;
    }
    // A player that left takes its stamp with it.
    function prune(seen, keys) {
        const s = {};
        for (const k of keys)
            if (seen && seen[k] !== undefined)
                s[k] = seen[k];
        return s;
    }
}

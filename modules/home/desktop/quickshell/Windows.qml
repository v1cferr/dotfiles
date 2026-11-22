pragma Singleton
// Which window is an app's, among the compositor's toplevels: the one place that guesses it.
import Quickshell
import Quickshell.Wayland

Singleton {
    // `names` are what the app may call itself (a desktop entry, a display name); the window whose
    // title holds `title` wins among its windows, else the first of them. Null with none.
    function find(names, title) {
        const tokens = names.map(t => (t || "").toLowerCase()).filter(t => t !== "");
        const mine = ToplevelManager.toplevels.values.filter(w => {
            const id = (w.appId || "").toLowerCase();
            return id !== "" && tokens.some(t => id === t || id.indexOf(t) >= 0 || t.indexOf(id) >= 0);
        });
        const exact = title && title.length > 3 ? mine.find(w => (w.title || "").indexOf(title) >= 0) : undefined;
        return exact || (mine.length ? mine[0] : null);
    }
}

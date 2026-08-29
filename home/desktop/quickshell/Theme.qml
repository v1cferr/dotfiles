pragma Singleton
// Quickshell's theme source. The PALETTE and the UI FONT come from Nix through the generated JSON
// (a FileView watches it, so qs reloads live); only the glass opacities are STYLE and stay here.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: theme

    // The pure palette coming from Nix; the fallbacks are Tokyo Night (in case the file is missing).
    FileView {
        id: paletteFile
        path: "/home/v1cferr/.config/theme/quickshell-colors.json"
        blockLoading: true // a SYNCHRONOUS read on the 1st access, so no color flash
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: pal
            property string bg: "#1a1b26"
            property string surface: "#1f2335"
            property string track: "#292e42"
            property string border: "#414868"
            property string text: "#c0caf5"
            property string subtext: "#a9b1d6"
            property string dim: "#565f89"
            property string accent: "#7aa2f7"
            property string blue: "#7aa2f7"
            property string cyan: "#7dcfff"
            property string sky: "#89ddff"
            property string teal: "#73daca"
            property string green: "#9ece6a"
            property string yellow: "#e0af68"
            property string orange: "#ff9e64"
            property string red: "#f7768e"
            property string magenta: "#bb9af7"
            property string purple: "#9d7cd8"
            property string pink: "#ff007c"
            property string uiFont: "JetBrainsMono Nerd Font" // it comes from my.fonts.ui
            property string shadow: "#0f0f0f"
        }
    }

    // The connectors coming from Nix (my.monitors, home/desktop/monitors.nix); the fallback is
    // the current setup, in case the file is missing, the same pattern as the palette above.
    FileView {
        id: monitorsFile
        path: "/home/v1cferr/.config/theme/monitors.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: mon
            property string primary: "DP-2"
            property string secondary: "HDMI-A-3"
        }
    }

    readonly property string primaryMonitor: mon.primary
    readonly property string secondaryMonitor: mon.secondary

    // It applies an opacity (the hex byte "aa") to a "#rrggbb" color, giving "#aarrggbb".
    function aa(hex, a) { return "#" + a + hex.slice(1); }

    // Base
    readonly property color colBg: aa(pal.bg, "f2")
    readonly property color colBgSolid: pal.bg // an opaque bg (text over an accent, say)
    readonly property color colCard: aa(pal.surface, "f2")
    readonly property color colBorder: pal.border
    readonly property color colText: pal.text
    readonly property color colDim: pal.dim
    readonly property color colTrack: pal.track

    // The accents (mapped onto the active theme's palette)
    readonly property color colAccent: pal.accent
    readonly property color colRed: pal.red
    readonly property color colGreen: pal.green
    readonly property color colPeach: pal.orange
    readonly property color colMauve: pal.magenta
    readonly property color colSapphire: pal.cyan
    readonly property color colBlue: pal.blue
    readonly property color colSky: pal.sky
    readonly property color colTeal: pal.teal
    readonly property color colYellow: pal.yellow
    readonly property color colPink: pal.pink
    readonly property color colLavender: pal.purple

    // The bar's pills / groups (the original design's opacities preserved)
    readonly property color colGroupBg: aa(pal.bg, "59")
    readonly property color colGroupBorder: aa(pal.border, "2e")
    readonly property color colHoverBorder: aa(pal.accent, "80")
    readonly property color colPillBg: aa(pal.bg, "db")
    readonly property color colPillBorder: aa(pal.border, "59")
    readonly property color colPillHoverBg: aa(pal.bg, "eb")

    // Workspaces
    readonly property color colWsActiveBg: aa(pal.accent, "d9")
    readonly property color colWsActiveBorder: aa(pal.accent, "e6")
    readonly property color colWsInactive: pal.subtext

    // The CALENDAR's "now" (the current month and today): a FILL already means a holiday and an
    // OUTLINE a facultative one, so today needs a third signal instead of a fourth color.
    readonly property color colNowBg: aa(pal.accent, "2b")

    // HOVER tokens (rule 11): this was written by hand in 7 files, 4 of them still in the OLD
    // Catppuccin palette, so "danger" was painted with a red from ANOTHER theme.
    readonly property color colHoverBg: aa(pal.border, "33"); // neutral (the default)
    readonly property color colHoverBgDanger: aa(pal.red, "33"); // a destructive action
    readonly property color colHoverBgOk: aa(pal.green, "33"); // a confirming action
    readonly property color colHoverBgAccent: aa(pal.accent, "33"); // a focused control
    // A MENU ROW has no border, so the background is the only signal, and 20% is invisible (1.11:1,
    // measured). The accent at 30% gives 1.77:1 AND changes hue. docs/notes/desktop/quickshell.md
    readonly property color colMenuHoverBg: aa(pal.accent, "4d"); // a menu row under the cursor
    readonly property color colMenuHoverBgDanger: aa(pal.red, "4d"); // the same, a destructive action
    // 120ms and not the Pill's 200ms: in a MENU the cursor crosses several items and 200ms leaves 2-3
    // lit at once.
    readonly property int hoverAnim: 120;

    readonly property string uiFont: pal.uiFont

    // The main monitor, falling back to the 1st available. It USED to be "DP-1", which does not exist
    // here, so it always fell into s[0] and the OSD could open on the TV.
    readonly property var screenPrimary: {
        const s = Quickshell.screens;
        for (let i = 0; i < s.length; i++)
            if (s[i].name === theme.primaryMonitor)
                return s[i];
        return s.length ? s[0] : null;
    }
}

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
        path: Quickshell.env("HOME") + "/.config/theme/quickshell-colors.json"
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
            property string motion: "subtle" // it comes from my.theme.motion
            property string glass: "perceptible" // it comes from my.theme.glass
            property int gapsOut: 12 // it comes from my.theme.gaps.outer
        }
    }

    // The connectors coming from Nix (my.monitors, modules/home/desktop/monitors.nix); the fallback is
    // the current setup, in case the file is missing, the same pattern as the palette above.
    FileView {
        id: monitorsFile
        path: Quickshell.env("HOME") + "/.config/theme/monitors.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: mon
            property string primary: "DP-2"
            property string secondary: "HDMI-A-3"
        }
    }

    // The glance band's height (my.dash.share, modules/home/desktop/quickshell/dash/band.nix).
    FileView {
        id: dashFile
        path: Quickshell.env("HOME") + "/.config/theme/dash.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
        JsonAdapter {
            id: dashCfg
            property real share: 0.35
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
    readonly property color colSubtext: pal.subtext // one step under colText, for a line that is not the subject
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
    readonly property color colNowBg: aa(pal.accent, "2b") // today's cell, and the month's name pill
    readonly property color colNowPanel: aa(pal.accent, "12") // the panel behind the WHOLE current month
    readonly property color colNowBorder: aa(pal.accent, "59") // that panel's edge, quieter than the ring

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
    // MOTION tokens, one per meaning, so a duration is never a literal in a consumer (rule 11).
    // my.theme.motion = "off" zeroes them all; the design and the numbers: docs/notes/desktop/motion.md
    readonly property bool motionReduced: pal.motion === "off"
    function ms(d) { return theme.motionReduced ? 0 : d; } // a one-off duration that still obeys "off"
    readonly property int motionFast: theme.ms(90) // a direct response to a key: the OSD's bars
    // 120ms: in a MENU the cursor crosses several items, and 200ms left 2-3 of them lit at once.
    readonly property int motionHover: theme.ms(120)
    readonly property int motionNormal: theme.ms(180) // something appearing or moving: a popover, an indicator
    readonly property int motionSlow: theme.ms(300) // a value settling: a meter, a progress bar
    // How long the pointer rests on a pill before its panel opens: a sweep across the bar opens nothing.
    readonly property int hoverIntent: 200

    // ── Tokenized geometry: Tokyo Night Adaptive Glass. The system: docs/notes/desktop/theme.md ──
    // Spacing on a 4 px grid, the only gaps and paddings a component may use.
    readonly property int sp1: 4
    readonly property int sp2: 8
    readonly property int sp3: 12
    readonly property int sp4: 16
    readonly property int sp6: 24
    readonly property int hairline: 1
    // Concentric radii: a surface is a control plus sp1 of padding, so its corner is the control's plus sp1.
    readonly property int radiusControl: 8
    readonly property int radiusSurface: radiusControl + sp1
    // The bar: ONE continuous 40 px Powerline across the screen, edge to edge, holding 28 px controls.
    readonly property int barHeight: 40
    readonly property int barControl: barHeight - sp3
    readonly property int barTop: 0 // flush with the screen's top edge
    readonly property int barSlant: sp2 // how far a Powerline divider leans across the bar's height
    readonly property int barCenterWidth: 64 // the logo's compartment, on the screen's exact center
    readonly property int barLogo: 22
    // Where floating things stop short of the screen's edge: Hyprland's gaps_out (appearance.lua).
    readonly property int screenInset: pal.gapsOut
    // The glance band: what share of a standing screen's height it takes, the bar INCLUDED. It starts
    // sp1 under the bar and ends where the windows' area begins. docs/notes/desktop/dash.md
    // Clamped here too: the option's type refuses more than 40%, and a hand-edited file must not get past it.
    readonly property real bandShare: Math.max(0.25, Math.min(0.4, dashCfg.share))
    readonly property int bandTop: barTop + barHeight + sp2
    function bandReserve(screenHeight) { return Math.round(screenHeight * theme.bandShare); }
    // Type scale (px). Mono everywhere, so a changing number never moves its neighbors.
    readonly property int fontMicro: 10 // a unit, a footnote
    readonly property int fontSmall: 11 // a bar label, a metadata line
    readonly property int fontBody: 12 // a panel row
    readonly property int fontLabel: 13 // a glyph in the bar, a card title
    readonly property int fontTitle: 14 // a panel title

    // ── Glass: three levels of see-through, in one of three profiles (my.theme.glass) ──
    // perceptible: flat, 90/92/96%. clear-gradient: bg at the top easing into the palette's surface at
    // the foot, 86->80 / 70->70 (the band: kitty's own 0.70, so it reads as a window) / 90 flat.
    // solid: opaque. The contrast: docs/notes/desktop/theme.md
    readonly property bool glassSolid: pal.glass === "solid"
    readonly property bool glassClear: pal.glass === "clear-gradient"
    function glassBg(a) { return theme.aa(pal.bg, theme.glassSolid ? "ff" : a); }
    function glassFoot(a) { return theme.aa(pal.surface, theme.glassSolid ? "ff" : a); }
    readonly property color colSurfaceBar: theme.glassBg(theme.glassClear ? "db" : "e6")
    readonly property color colSurfaceBarFoot: theme.glassClear ? theme.glassFoot("cc") : theme.colSurfaceBar
    readonly property color colSurfaceCard: theme.glassBg(theme.glassClear ? "b3" : "eb")
    readonly property color colSurfaceCardFoot: theme.glassClear ? theme.glassFoot("b3") : theme.colSurfaceCard
    readonly property color colSurfacePop: theme.glassBg(theme.glassClear ? "e6" : "f5") // dense text: never a gradient
    readonly property color colEdge: aa(pal.border, "8c") // a surface's hairline
    readonly property color colSheen: aa(pal.text, "0f") // the 1 px light along a surface's top edge
    readonly property color colBarCenter: theme.glassSolid ? pal.surface : aa(pal.surface, "f0") // the logo's compartment
    readonly property color colBarAccent: aa(pal.accent, "b3") // the thin blue under the logo
    // States of a control on glass: a neutral fill, so the accent stays free to mean "active".
    readonly property color colHoverFill: aa(pal.text, "14")
    readonly property color colPressFill: aa(pal.text, "24")
    readonly property color colSelectFill: aa(pal.accent, "2e")
    readonly property real opacityDisabled: 0.4

    // A panel narrower than this cannot hold the bar's full set, and it is where the glance band
    // takes over instead. Measured against the widest left group: docs/notes/desktop/bar.md
    readonly property int compactWidth: 1600;

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

    // Is the SECONDARY there right now? With the TV off its workspaces fall onto the primary, and
    // the bar has to take them over. Reactive: Quickshell.screens follows the hotplug.
    readonly property bool secondaryConnected: {
        const s = Quickshell.screens;
        for (let i = 0; i < s.length; i++)
            if (s[i].name === theme.secondaryMonitor)
                return true;
        return false;
    }
}

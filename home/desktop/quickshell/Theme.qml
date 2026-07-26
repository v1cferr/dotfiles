pragma Singleton
// Fonte ÚNICA de verdade do tema (paleta Tokyo Night + acentos, fonte de UI e a
// tela principal). Antes a paleta era reescrita em ~7 arquivos e já divergia
// (ex.: colPeach #fab387 vs #ff9e64). Referencie como Theme.colX / Theme.uiFont.
import Quickshell
import QtQuick

Singleton {
    id: theme

    // Base
    readonly property color colBg: "#f21a1b26"
    readonly property color colCard: "#f21f2336"
    readonly property color colBorder: "#414868"
    readonly property color colText: "#c0caf5"
    readonly property color colDim: "#565f89"
    readonly property color colTrack: "#283041"

    // Acentos
    readonly property color colAccent: "#7aa2f7"
    readonly property color colRed: "#f38ba8"
    readonly property color colGreen: "#a6e3a1"
    readonly property color colPeach: "#fab387"
    readonly property color colMauve: "#cba6f7"
    readonly property color colSapphire: "#74c7ec"
    readonly property color colBlue: "#89b4fa"
    readonly property color colSky: "#89dceb"
    readonly property color colTeal: "#94e2d5"
    readonly property color colYellow: "#f9e2af"
    readonly property color colPink: "#f5c2e7"
    readonly property color colLavender: "#b4befe"

    // Pílulas / grupos da barra
    readonly property color colGroupBg: "#591a1b26"
    readonly property color colGroupBorder: "#2e414868"
    readonly property color colHoverBorder: "#807aa2f7"
    readonly property color colPillBg: "#db1a1b26"
    readonly property color colPillBorder: "#59414868"
    readonly property color colPillHoverBg: "#eb1a1b26"

    // Workspaces
    readonly property color colWsActiveBg: "#d97aa2f7"
    readonly property color colWsActiveBorder: "#e67aa2f7"
    readonly property color colWsInactive: "#a9b1d6"

    readonly property string uiFont: "JetBrainsMono Nerd Font"

    // Monitor principal (DP-1) com fallback — usado por barra/painéis/OSD.
    readonly property var screenDP1: {
        const s = Quickshell.screens;
        for (let i = 0; i < s.length; i++)
            if (s[i].name === "DP-1")
                return s[i];
        return s.length ? s[0] : null;
    }
}

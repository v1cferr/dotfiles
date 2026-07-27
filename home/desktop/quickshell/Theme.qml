pragma Singleton
// Fonte de tema do Quickshell. A PALETA vem do Nix (my.theme) via o JSON gerado por
// home/desktop/palette.nix — trocar de tema lá recolore a barra toda no próximo rebuild
// (o FileView observa o arquivo, então o qs recarrega ao vivo). As opacidades do glass
// e a fonte de UI são ESTILO e ficam aqui. Referencie como Theme.colX / Theme.uiFont.
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: theme

    // Paleta pura vinda do Nix; fallbacks = Tokyo Night (caso o arquivo falte).
    FileView {
        id: paletteFile
        path: "/home/v1cferr/.config/theme/quickshell-colors.json"
        blockLoading: true // leitura SÍNCRONA no 1º acesso → sem flash de cor
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
            property string shadow: "#0f0f0f"
        }
    }

    // Aplica opacidade (byte hex "aa") a uma cor "#rrggbb" → "#aarrggbb".
    function aa(hex, a) { return "#" + a + hex.slice(1); }

    // Base
    readonly property color colBg: aa(pal.bg, "f2")
    readonly property color colCard: aa(pal.surface, "f2")
    readonly property color colBorder: pal.border
    readonly property color colText: pal.text
    readonly property color colDim: pal.dim
    readonly property color colTrack: pal.track

    // Acentos (mapeados p/ a paleta do tema ativo)
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

    // Pílulas / grupos da barra (opacidades do design original preservadas)
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

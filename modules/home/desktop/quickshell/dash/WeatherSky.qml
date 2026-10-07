pragma Singleton
// The weather's colors, shared by every weather surface of the band: the sky's (a glyph says sun,
// rain, or neither) and the TEMPERATURE scale, the theme's own hues from cold to hot, interpolated
// per degree so a chart can be painted by the reading itself.
import Quickshell
import QtQuick
import "root:/"

Singleton {
    id: sky

    function color(code) {
        if (code === 0 || code === 1)
            return Theme.colYellow;
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95)
            return Theme.colSky;
        return Theme.colSubtext;
    }

    // Degrees Celsius -> the theme's hue for it. The stops are São Carlos' range, not the planet's:
    // a 19° night and a 31° afternoon have to look different, not both "mild".
    readonly property var stops: [[8, Theme.colBlue], [15, Theme.colSky], [19, Theme.colTeal], [22, Theme.colGreen], [26, Theme.colYellow], [30, Theme.colPeach], [34, Theme.colRed]]
    function temp(t) {
        const s = sky.stops;
        if (t <= s[0][0])
            return s[0][1];
        for (let i = 1; i < s.length; i++) {
            if (t <= s[i][0]) {
                const f = (t - s[i - 1][0]) / (s[i][0] - s[i - 1][0]);
                const a = s[i - 1][1], b = s[i][1];
                return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1);
            }
        }
        return s[s.length - 1][1];
    }

    // Canvas wants CSS colors; a QML color would stringify as #AARRGGBB, which CSS reads wrong.
    function css(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
    }
}

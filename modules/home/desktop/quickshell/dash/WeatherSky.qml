pragma Singleton
// The sky's color, shared by today's glyph and the month's forecast days: sun, rain, or neither.
import Quickshell
import QtQuick
import "root:/"

Singleton {
    function color(code) {
        if (code === 0 || code === 1)
            return Theme.colYellow;
        if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95)
            return Theme.colSky;
        return Theme.colSubtext;
    }
}

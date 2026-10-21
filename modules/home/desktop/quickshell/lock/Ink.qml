// Reads the print under the type once it is shown: a 192 px grab of the screen into InkMath, which
// picks the side, the ink and how much soft shade the type needs to stay AA.
import QtQuick
import "root:/"

Item {
    id: ink

    required property Item target // what the type sits on (the Wallpaper)
    property var zones: [] // the type's zones on the LEFT, {x, y, w, h} as fractions of the screen
    property real ratio: 4.5
    property string light: Theme.colText
    property string dark: "#1a1b26"
    property var result: ({
            side: "left",
            ink: "light",
            ratio: 0,
            shade: 0.6
        })
    property bool measured: false
    readonly property int sampleH: Math.max(1, Math.round(192 * ink.target.height / Math.max(1, ink.target.width)))

    InkMath {
        id: math
    }

    function measure() {
        if (ink.measured)
            return;
        ink.target.grabToImage(r => sample.source = r.url, Qt.size(192, ink.sampleH));
    }

    // The grab, as an Image the canvas can draw (a canvas cannot load a grab's URL itself).
    Image {
        id: sample
        width: 192
        height: ink.sampleH
        visible: false
        cache: false
        onStatusChanged: if (status === Image.Ready)
            canvas.requestPaint()
    }
    Canvas {
        id: canvas
        width: 192
        height: ink.sampleH
        visible: false
        onPaint: {
            if (sample.status !== Image.Ready)
                return;
            const ctx = canvas.getContext("2d");
            ctx.drawImage(sample, 0, 0, canvas.width, canvas.height);
            const d = ctx.getImageData(0, 0, canvas.width, canvas.height);
            ink.result = math.decide(d.data, canvas.width, canvas.height, ink.zones, {
                light: String(ink.light),
                dark: String(ink.dark)
            }, ink.ratio);
            ink.measured = true;
        }
    }
}

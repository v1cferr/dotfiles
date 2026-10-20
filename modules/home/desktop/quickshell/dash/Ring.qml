// A share as a ring: the track all round, the value as an arc from the top, the number in its middle.
// One canvas, repainted only when the value or the size changes: nothing here animates on its own.
import QtQuick
import "root:/"

Item {
    id: ring
    property real value: NaN // 0 to 100; NaN draws the track alone and "–"
    property color tone: Theme.colAccent
    property string caption: ""
    property int thickness: 8
    implicitWidth: 104
    implicitHeight: 104

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            const ctx = cv.getContext("2d");
            ctx.reset();
            const r = Math.min(width, height) / 2 - ring.thickness / 2;
            const cx = width / 2, cy = height / 2;
            ctx.lineWidth = ring.thickness;
            ctx.lineCap = "round";
            ctx.strokeStyle = Theme.colTrack;
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.stroke();
            if (isNaN(ring.value))
                return;
            const f = Math.max(0, Math.min(1, ring.value / 100));
            if (f <= 0)
                return;
            ctx.strokeStyle = ring.tone;
            ctx.beginPath();
            ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + f * 2 * Math.PI);
            ctx.stroke();
        }
    }
    onValueChanged: cv.requestPaint()
    onToneChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()

    Column {
        anchors.centerIn: parent
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: isNaN(ring.value) ? "–" : Math.round(ring.value) + "%"
            color: ring.tone
            font.family: Theme.uiFont
            font.pixelSize: 24
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: ring.caption
            color: Theme.colSubtext
            font.family: Theme.uiFont
            font.pixelSize: 11
            font.letterSpacing: 2
        }
    }
}

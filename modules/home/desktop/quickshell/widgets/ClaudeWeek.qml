// The week of Claude's weekly limit as ONE readable picture, for the band and the lock alike: the
// share used as a step line (a running total: each reading holds until the next) across the limit's
// own week, from its last renewal to the next, guides at 50% and 100%, the days, the resets dotted,
// the value now at the line's end, and, with `pace`, the even-spending line it can be read against.
// Under the pointer: the day, the hour, the share (and the pace). docs/notes/desktop/dash.md
import QtQuick
import "root:/"
import "root:/dash"

Item {
    id: week

    // The caller's style: the band's (mono, en-US) by default, the lock's when it says so.
    property color tone: Theme.colMauve
    property string fontFamily: Theme.uiFont
    property string localeName: "en_US"
    property bool pace: false
    property var words: ({
            used: "used",
            reset: "reset",
            noData: "no data before",
            pace: "pace"
        })
    property string tipStyle: "band" // "band" (the band's tip card) | "glass" (the lock's dark pill)
    readonly property var loc: Qt.locale(week.localeName)

    readonly property real span: 7 * 86400
    // The frame is the limit's own week, from its last renewal to the next (the line ends at now, the
    // rest is the week still ahead); with no window open, the last 7 days and no pace.
    readonly property real now: ClaudeUsage.now
    readonly property bool windowed: ClaudeUsage.weekly.resets > week.now
    readonly property real t1: week.windowed ? ClaudeUsage.weekly.resets : week.now
    readonly property real t0: week.t1 - week.span
    readonly property bool showPace: week.pace && week.windowed
    // Even spending: the share the week would show at time t if used evenly up to the renewal.
    function paceAt(ts) {
        return Math.max(0, Math.min(100, 100 * (ts - week.t0) / week.span));
    }
    // The readings in the window, oldest first, plus the last one before it (it holds into the window).
    readonly property var points: {
        const h = (ClaudeUsage.history || []).filter(p => p && typeof p.ts === "number" && p.w !== null && p.w !== undefined).sort((a, b) => a.ts - b.ts);
        const out = [];
        for (let i = 0; i < h.length; i++) {
            if (h[i].ts >= week.t0)
                out.push({
                    ts: h[i].ts,
                    w: Math.max(0, Math.min(100, h[i].w))
                });
            else if (i + 1 < h.length && h[i + 1].ts >= week.t0)
                out.push({
                    ts: week.t0,
                    w: Math.max(0, Math.min(100, h[i].w))
                });
        }
        return out;
    }
    // A reset is a reading lower than the one before it.
    readonly property var resets: {
        const out = [];
        for (let i = 1; i < week.points.length; i++)
            if (week.points[i].w < week.points[i - 1].w)
                out.push(week.points[i].ts);
        return out;
    }
    readonly property int axisW: 40 // the % labels
    readonly property int daysH: 20 // the day labels
    readonly property real plotX: week.axisW
    readonly property real plotW: week.width - week.axisW - 46 // room for the value at the end
    readonly property real plotH: week.height - week.daysH - 8
    property int hover: -1 // index into points
    property real hoverTs: 0

    function xAt(ts) {
        return week.plotX + week.plotW * (ts - week.t0) / week.span;
    }
    function yAt(w) {
        return 4 + week.plotH * (1 - w / 100);
    }

    onPointsChanged: cv.requestPaint()
    onWidthChanged: cv.requestPaint()
    onHeightChanged: cv.requestPaint()
    onHoverChanged: cv.requestPaint()
    onShowPaceChanged: cv.requestPaint()

    Canvas {
        id: cv
        anchors.fill: parent
        onPaint: {
            const ctx = cv.getContext("2d");
            ctx.reset();
            const x0 = week.plotX, x1 = week.plotX + week.plotW;
            // Guides: 0 solid and faint, 50 and 100 dashed.
            ctx.strokeStyle = Theme.colTrack;
            ctx.lineWidth = 1;
            for (const g of [0, 50, 100]) {
                ctx.setLineDash(g === 0 ? [] : [3, 4]);
                ctx.beginPath();
                ctx.moveTo(x0, Math.round(week.yAt(g)) + 0.5);
                ctx.lineTo(x1, Math.round(week.yAt(g)) + 0.5);
                ctx.stroke();
            }
            // Resets: a dotted vertical line where the share dropped.
            ctx.strokeStyle = Theme.colDim;
            ctx.setLineDash([2, 3]);
            for (const r of week.resets) {
                const x = Math.round(week.xAt(r)) + 0.5;
                ctx.beginPath();
                ctx.moveTo(x, week.yAt(100));
                ctx.lineTo(x, week.yAt(0));
                ctx.stroke();
            }
            // The pace: even spending from the last renewal (0%) to the next (100%).
            if (week.showPace) {
                ctx.strokeStyle = Theme.colSubtext;
                ctx.globalAlpha = 0.6;
                ctx.setLineDash([5, 5]);
                ctx.beginPath();
                ctx.moveTo(week.xAt(week.t0), week.yAt(0));
                ctx.lineTo(week.xAt(week.t1), week.yAt(100));
                ctx.stroke();
                ctx.globalAlpha = 1;
            }
            ctx.setLineDash([]);
            const p = week.points;
            if (p.length < 1)
                return;
            // The step line and a faint fill under it, held to "now".
            const path = () => {
                ctx.beginPath();
                ctx.moveTo(week.xAt(p[0].ts), week.yAt(p[0].w));
                for (let i = 1; i < p.length; i++) {
                    ctx.lineTo(week.xAt(p[i].ts), week.yAt(p[i - 1].w));
                    ctx.lineTo(week.xAt(p[i].ts), week.yAt(p[i].w));
                }
                ctx.lineTo(week.xAt(week.now), week.yAt(p[p.length - 1].w));
            };
            path();
            ctx.lineTo(week.xAt(week.now), week.yAt(0));
            ctx.lineTo(week.xAt(p[0].ts), week.yAt(0));
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(week.tone.r, week.tone.g, week.tone.b, 0.14);
            ctx.fill();
            path();
            ctx.strokeStyle = week.tone;
            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.stroke();
        }
    }

    // The % axis.
    Repeater {
        model: [0, 50, 100]
        Text {
            required property int modelData
            x: 0
            width: week.axisW - 8
            horizontalAlignment: Text.AlignRight
            y: week.yAt(modelData) - height / 2
            text: modelData + "%"
            color: Theme.colDim
            font.family: week.fontFamily
            font.pixelSize: Theme.fontMicro
        }
    }
    // The days: a short name at each local midnight in the window.
    Repeater {
        model: {
            const out = [];
            const d = new Date(week.t0 * 1000);
            d.setHours(24, 0, 0, 0);
            for (; d.getTime() / 1000 < week.t1 - 3600; d.setDate(d.getDate() + 1))
                out.push(d.getTime() / 1000);
            return out;
        }
        Item {
            required property real modelData
            x: week.xAt(modelData)
            y: week.yAt(0)
            Rectangle {
                width: 1
                height: 4
                color: Theme.colDim
            }
            Text {
                x: 4
                y: 4
                text: week.loc.toString(new Date(modelData * 1000), "ddd").replace(".", "")
                color: Theme.colDim
                font.family: week.fontFamily
                font.pixelSize: Theme.fontMicro
            }
        }
    }
    // The pace's name, where its line leaves the frame.
    Text {
        visible: week.showPace
        x: week.xAt(week.t1) - width - 4
        y: week.yAt(100) + 6
        text: week.words.pace
        color: Theme.colSubtext
        font.family: week.fontFamily
        font.pixelSize: Theme.fontMicro
        font.italic: true
    }
    // Before the first reading the week is unknown, not zero: said once, faintly, in that gap.
    Text {
        readonly property real first: week.points.length ? week.points[0].ts : week.now
        visible: first - week.t0 > 12 * 3600
        x: week.xAt(week.t0) + (week.xAt(first) - week.xAt(week.t0) - width) / 2
        y: week.yAt(50) - height / 2
        width: Math.min(implicitWidth, week.xAt(first) - week.xAt(week.t0) - 8)
        elide: Text.ElideRight
        text: week.words.noData + " " + week.loc.toString(new Date(first * 1000), "ddd HH:mm").replace(".", "")
        color: Theme.colDim
        font.family: week.fontFamily
        font.pixelSize: Theme.fontSmall
        font.italic: true
    }
    // The value now, at the end of the line.
    Text {
        visible: week.points.length > 0
        x: week.xAt(week.now) + 6
        y: week.points.length ? week.yAt(week.points[week.points.length - 1].w) - height / 2 : 0
        text: week.points.length ? Math.round(week.points[week.points.length - 1].w) + "%" : ""
        color: week.tone
        font.family: week.fontFamily
        font.pixelSize: Theme.fontLabel
        font.bold: true
    }

    // The readout: the reading in force at the pointer (the step's own value).
    MouseArea {
        x: week.plotX
        width: week.plotW
        height: week.height
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: mouse => {
            const ts = Math.min(week.now, week.t0 + (mouse.x / week.plotW) * week.span);
            let k = -1;
            for (let i = 0; i < week.points.length; i++)
                if (week.points[i].ts <= ts)
                    k = i;
            week.hover = k;
            week.hoverTs = ts;
        }
        onExited: week.hover = -1
    }
    Rectangle {
        visible: week.hover >= 0
        x: Math.round(week.xAt(week.hoverTs))
        y: week.yAt(100)
        width: 1
        height: week.plotH
        color: Theme.colText
        opacity: 0.35
    }
    Rectangle {
        visible: week.hover >= 0
        width: 8
        height: 8
        radius: 4
        color: week.tone
        border.width: 2
        border.color: Theme.colText
        x: week.xAt(week.hoverTs) - 4
        y: week.hover >= 0 ? week.yAt(week.points[week.hover].w) - 4 : 0
    }
    Rectangle {
        id: tip
        readonly property bool glass: week.tipStyle === "glass"
        visible: week.hover >= 0
        z: 2
        radius: tip.glass ? 6 : Theme.radiusControl
        color: tip.glass ? Qt.rgba(0.06, 0.07, 0.1, 0.88) : Theme.colSurfaceTip
        border.width: tip.glass ? 0 : Theme.hairline
        border.color: Theme.colEdge
        width: tipText.implicitWidth + 2 * Theme.sp2
        height: tipText.implicitHeight + 2 * Theme.sp1
        x: Math.max(0, Math.min(week.width - width, week.xAt(week.hoverTs) - width / 2))
        y: week.yAt(100) + Theme.sp1
        Text {
            id: tipText
            anchors.centerIn: parent
            text: {
                if (week.hover < 0)
                    return "";
                const near = week.resets.some(r => Math.abs(week.xAt(r) - week.xAt(week.hoverTs)) < 6);
                const when = week.loc.toString(new Date(week.hoverTs * 1000), "ddd HH:mm").replace(".", "");
                return when + "  ·  " + Math.round(week.points[week.hover].w) + "% " + week.words.used + (week.showPace ? "  ·  " + week.words.pace + " " + Math.round(week.paceAt(week.hoverTs)) + "%" : "") + (near ? "  ·  " + week.words.reset : "");
            }
            color: Theme.colText
            font.family: week.fontFamily
            font.pixelSize: tip.glass ? 15 : Theme.fontSmall
        }
    }
}

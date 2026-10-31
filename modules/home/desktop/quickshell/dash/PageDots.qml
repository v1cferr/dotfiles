// Where a carousel is and when it turns: a dot per page, the current one a pill that fills as its
// time runs out, and a pause at the end that holds the page until clicked again. The fill moves in
// whole pixels (one every interval / pillW ms), so it stays sharp and costs a repaint per pixel, not
// a frame per vsync.
// It is drawn in REAL pixels, not the band's design units: the cards scale their content by k (0.749
// on the LG), which would put a 6 unit dot on 4.5 pixels. The `px` box undoes k and snaps to the
// window's pixel grid, so every edge below lands whole. The why: docs/notes/desktop/dash.md
import QtQuick
import "root:/"

Item {
    id: dots
    property var order: [] // the page ids, in rotation order
    property int current: 0
    property int interval: 15000 // how long a page stays
    property bool held: false // the owner's own holds: the pointer, an open detail, a clicked alert
    property Text title: null // the header's title: the row centers on its capitals, not its line box
    readonly property bool paused: pause.paused
    function togglePause() {
        pause.paused = !pause.paused;
    }
    signal advance
    signal jump(int id)

    readonly property int pillW: 22
    property int tick: 0 // pixels of the pill already filled
    onCurrentChanged: dots.tick = 0

    // Design units per real pixel, and where this item falls in the window, read back from the scene
    // whenever the header moves it and once more after the band settles (the cards above it are laid
    // out after this item is). Never on width: the width comes from k, and that would be a loop.
    // `top` is where the 16 px row starts in the window: centered on the title's capitals when there
    // is one (a line box also holds the descenders, so its middle sits low), rounded to a whole pixel.
    property var geo: ({
            k: 1,
            x: 0,
            y: 0,
            top: 0
        })
    function snap() {
        const o = dots.mapToItem(null, 0, 0), e = dots.mapToItem(null, 100, 0);
        const k = (e.x - o.x) / 100 || 1;
        let mid = o.y + 8;
        if (dots.title) {
            const base = dots.title.mapToItem(null, 0, dots.title.baselineOffset).y;
            mid = base + (caps.tightBoundingRect.y + caps.tightBoundingRect.height / 2) * k;
        }
        dots.geo = {
            k: k,
            x: o.x,
            y: o.y,
            top: Math.round(mid - 8)
        };
    }
    TextMetrics {
        id: caps
        font: dots.title ? dots.title.font : Qt.font({})
        text: "H"
    }
    onXChanged: Qt.callLater(dots.snap)
    onYChanged: Qt.callLater(dots.snap)
    onVisibleChanged: Qt.callLater(dots.snap)
    Component.onCompleted: Qt.callLater(dots.snap)
    Timer {
        interval: 1000
        running: true
        onTriggered: dots.snap()
    }
    implicitWidth: row.implicitWidth / dots.geo.k
    implicitHeight: 16 / dots.geo.k

    Timer {
        interval: Math.round(dots.interval / dots.pillW)
        repeat: true
        running: !dots.held && !dots.paused && dots.order.length > 1
        onTriggered: {
            if (++dots.tick < dots.pillW)
                return;
            dots.tick = 0;
            dots.advance();
        }
    }
    Item {
        id: px
        scale: 1 / dots.geo.k
        transformOrigin: Item.TopLeft
        // Snapped by the RIGHT edge, one pixel past the padding: the title's first letter sits a pixel
        // inside its box (the glyph's side bearing), so the ink gaps match on both sides of the card.
        x: (Math.ceil(dots.geo.x + row.width) + 1 - dots.geo.x - row.width) / dots.geo.k
        y: (dots.geo.top - dots.geo.y) / dots.geo.k
        Row {
            id: row
            spacing: 6
            height: 16
            Repeater {
                model: dots.order
                delegate: Rectangle {
                    id: dot
                    required property int modelData
                    readonly property bool on: dots.current === modelData
                    y: 5
                    width: on ? dots.pillW : 6
                    height: 6
                    radius: 3
                    color: Theme.colTrack
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.motionNormal
                            easing.type: Easing.OutCubic
                        }
                    }
                    // The time spent on the page: full while paused, a dot growing into the pill otherwise.
                    Rectangle {
                        visible: dot.on
                        width: Math.min(dot.width, dots.paused ? dots.pillW : Math.max(6, dots.tick))
                        height: 6
                        radius: 3
                        color: Theme.colAccent
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dots.jump(dot.modelData)
                    }
                }
            }
            // The pause stands apart from the dots: a zero-wide spacer doubles the gap to 12 px.
            Item {
                width: 0
                height: 16
            }
            PauseToggle {
                id: pause
            }
        }
    }
}

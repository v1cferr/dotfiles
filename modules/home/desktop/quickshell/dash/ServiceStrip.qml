// The band's bottom strip: the machine's services, three cards a page, turning every 10 s like the
// month column, held under the pointer. Trouble first, then the heaviest by RAM or by CPU (a click
// on the header switches), so page one is always what matters most. The why: docs/notes/desktop/dash.md
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: strip

    readonly property int perPage: 3
    readonly property var all: Services.list
    readonly property int pageCount: Math.max(1, Math.ceil(strip.all.length / strip.perPage))
    property int page: 0
    property bool held: false // the band holds it on its trouble page after an alert was clicked
    onPageCountChanged: if (strip.page >= strip.pageCount)
        strip.page = 0

    readonly property bool hovered: hover.hovered // the band's keys turn this strip while the pointer is on it
    function togglePause() {
        stripDots.togglePause();
    }
    function step(d) {
        strip.page = (strip.page + d + strip.pageCount) % strip.pageCount;
    }

    spacing: 8

    HoverHandler {
        id: hover
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => strip.step(event.angleDelta.y > 0 ? -1 : 1)
    }

    // ── Header: the count that matters, and where the carousel is ──
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Text {
            id: stripTitle
            text: "SERVICES"
            color: Theme.colSubtext
            font.family: Theme.uiFont
            font.pixelSize: 13
            font.letterSpacing: 2
        }
        Text {
            readonly property int bad: strip.all.length - Services.upCount
            text: strip.all.length === 0 ? "no data yet: dash-services-meta has not answered" : (bad === 0 ? "all " + strip.all.length + " up" : bad + " of " + strip.all.length + " need a look")
            color: strip.all.length === 0 ? Theme.colDim : (bad === 0 ? Theme.colGreen : Theme.colPeach)
            font.family: Theme.uiFont
            font.pixelSize: 13
            font.bold: true
        }
        // What the order means, and a click to switch it.
        Text {
            text: "· by " + (Services.sortBy === "ram" ? "RAM" : "CPU, 2 min avg") + "  ⇅"
            color: sortArea.containsMouse ? Theme.colAccent : Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: 13
            MouseArea {
                id: sortArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Services.sortBy = Services.sortBy === "ram" ? "cpu" : "ram";
                    strip.page = 0;
                }
            }
        }
        Item {
            Layout.fillWidth: true
        }
        PageDots {
            id: stripDots
            visible: strip.pageCount > 1
            order: Array.from({
                length: strip.pageCount
            }, (_, i) => i)
            current: strip.page
            title: stripTitle
            interval: 10000
            held: !strip.visible || hover.hovered || strip.held
            onAdvance: strip.step(1)
            onJump: id => strip.page = id
        }
    }

    // ── The pages: one long row that slides, so the carousel moves like a strip of paper ──
    Item {
        id: viewport
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true

        Row {
            id: rail
            x: -strip.page * viewport.width
            Behavior on x {
                NumberAnimation {
                    duration: Theme.ms(520)
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                model: strip.pageCount
                delegate: Item {
                    id: pg
                    required property int index
                    width: viewport.width
                    height: viewport.height

                    RowLayout {
                        anchors.fill: parent
                        spacing: 12
                        Repeater {
                            model: strip.all.slice(pg.index * strip.perPage, (pg.index + 1) * strip.perPage)
                            delegate: ServiceCard {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredWidth: 0
                                s: modelData
                            }
                        }
                        // A short last page keeps its cards at the same width.
                        Repeater {
                            model: Math.max(0, strip.perPage - strip.all.slice(pg.index * strip.perPage, (pg.index + 1) * strip.perPage).length)
                            delegate: Item {
                                Layout.fillWidth: true
                                Layout.preferredWidth: 0
                            }
                        }
                    }
                }
            }
        }
    }
}

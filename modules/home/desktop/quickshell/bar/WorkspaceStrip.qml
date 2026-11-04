// The ADAPTIVE WORKSPACE RAIL: one monitor's workspaces in ONE "\" cell, the active one under a
// sliding inner "\" of the same slope. Occupied reads bright, empty dim; a new window is a yellow
// tick under the number and a request for attention the active shape in red, neither pulsing.
// The rail, its model (orphans of a gone secondary) and the 0.55 dispatch trap: docs/notes/desktop/bar.md
import QtQuick
import QtQuick.Shapes
import "root:/"
import "root:/widgets"

SlantCell {
    id: strip
    required property var host // the Bar's Scope: the workspace state lives there
    property string monitor: ""
    property var barContent: null
    property var barWindow: null

    readonly property var ids: strip.host.wsModelFor(strip.monitor)
    // wsRep.count is read so the binding wakes up once the buttons exist.
    readonly property Item act: {
        const i = wsRep.count > 0 ? strip.ids.indexOf(strip.host.wsActive[strip.monitor]) : -1;
        return i >= 0 ? wsRep.itemAt(i) : null;
    }
    property bool placed: false // no slide in from x = 0 on the first frame
    lean: -1
    implicitWidth: Math.ceil((wsRow.implicitWidth + 2 * Theme.sp2) / 4) * 4

    // An inner "\" for a button: 18 px tall at y 3, a 6 px lean, the cell's own 1:3 slope.
    component InnerSlant: Shape {
        id: inner
        property real w: 0
        property color tone: Theme.colAccent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: "transparent"
            fillColor: inner.tone
            startX: 0
            startY: 3
            PathLine {
                x: inner.w
                y: 3
            }
            PathLine {
                x: inner.w + 6
                y: 21
            }
            PathLine {
                x: 6
                y: 21
            }
            PathLine {
                x: 0
                y: 3
            }
        }
    }

    // The ACTIVE workspace is ONE shape that eases to its button, so a switch reads as a move.
    InnerSlant {
        id: ind
        visible: strip.act !== null
        x: wsRow.x + (strip.act ? strip.act.x : 0)
        w: strip.act ? strip.act.width : 0
        tone: Qt.alpha(Theme.colAccent, 0.22)
        onVisibleChanged: if (visible)
            Qt.callLater(() => strip.placed = true)
        Behavior on x {
            enabled: strip.placed
            NumberAnimation {
                duration: Theme.motionNormal
                easing.type: Easing.OutCubic
            }
        }
        Behavior on w {
            enabled: strip.placed
            NumberAnimation {
                duration: Theme.motionNormal
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        id: wsRow
        x: Theme.sp2 + strip.dx / 2
        height: Theme.barCell
        Repeater {
            id: wsRep
            model: strip.ids
            delegate: Item {
                id: btn
                required property int modelData
                readonly property bool active: strip.host.wsActive[strip.monitor] === btn.modelData
                readonly property bool exists: strip.host.wsExist[btn.modelData] === true
                readonly property bool urgent: strip.host.wsUrgent[btn.modelData] === true
                readonly property bool activity: strip.host.wsActivity[btn.modelData] === true

                // ONE width for every number, from a template: "01" and "08" never differ.
                implicitWidth: Math.ceil((tmNum.advanceWidth + 2 * Theme.sp2) / 4) * 4
                implicitHeight: Theme.barCell

                // Asking for attention: the active shape, in the alert color, until visited.
                InnerSlant {
                    visible: btn.urgent && !btn.active
                    w: btn.width
                    tone: Qt.alpha(Theme.colCrit, 0.22)
                }
                InnerSlant {
                    visible: area.containsMouse && !btn.active && !btn.urgent
                    w: btn.width
                    tone: Theme.colHoverFill
                }
                Text {
                    id: num
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: 3 // the inner shape's center line
                    text: strip.host.wsLabel(btn.modelData)
                    color: btn.active ? Theme.colAccent : (btn.urgent ? Theme.colCrit : (btn.exists ? Theme.colText : Theme.colDim))
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.motionNormal
                        }
                    }
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontBody
                    font.bold: btn.active || btn.exists || btn.urgent
                }
                // A window opened here: an 8 px yellow tick under the number. Visiting clears it.
                Rectangle {
                    visible: btn.activity && !btn.active && !btn.urgent
                    x: Math.round(num.x + (num.width - 8) / 2)
                    y: 19
                    width: 8
                    height: 2
                    radius: 1
                    color: Theme.colWarn
                }
                Accessible.role: Accessible.Button
                Accessible.name: "Workspace " + strip.host.wsLabel(btn.modelData) + (btn.active ? ", active" : (btn.exists ? ", occupied" : ", empty")) + (btn.urgent ? ", asks for attention" : (btn.activity ? ", new window" : ""))
                MouseArea {
                    id: area
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onContainsMouseChanged: {
                        if (containsMouse)
                            strip.host.hintWs = btn.modelData;
                        strip.host.hoverHint("ws", btn, strip.barContent, strip.barWindow, containsMouse);
                    }
                    // `hl.dsp.workspace` is a TABLE; what switches is focus (0.55's Lua dispatch).
                    onClicked: {
                        strip.host.hideHint();
                        strip.host.launch(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + btn.modelData + " })"]);
                    }
                }
            }
        }
    }
    TextMetrics {
        id: tmNum
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
        font.bold: true
        text: "00"
    }
}

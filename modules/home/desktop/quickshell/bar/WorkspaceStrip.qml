// The ADAPTIVE WORKSPACE RAIL: one monitor's workspaces in ONE "\" cell, the active one under a
// sliding inner "\" of the same slope. Each number carries its apps' icons (one per app, up to 3,
// then +N; a click focuses that window); occupied reads bright, empty dim; a new window is a yellow
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
    // The icons need room the standing screen's compact bar does not have.
    property bool withApps: true
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
                // The apps, on the full bar only: the standing screen's band has the room for them.
                readonly property var apps: strip.withApps ? strip.host.wsApps(btn.modelData) : []
                readonly property var shown: btn.apps.slice(0, 3)

                // The number from a template ("01" and "08" never differ), then its icons.
                implicitWidth: Math.ceil((numBox.width + (btn.shown.length > 0 ? appRow.implicitWidth + Theme.sp1 : 0) + 2 * Theme.sp2) / 4) * 4
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
                Item {
                    id: numBox
                    x: Theme.sp2 + 3 // the inner shape's center line
                    width: Math.ceil(tmNum.advanceWidth)
                    height: Theme.barCell
                }
                Text {
                    id: num
                    anchors.centerIn: numBox
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
                Row {
                    id: appRow
                    z: 1 // above the button's area, so an icon's own click wins
                    visible: btn.shown.length > 0
                    x: numBox.x + numBox.width + Theme.sp1
                    height: Theme.barCell
                    spacing: Theme.sp1
                    Repeater {
                        model: btn.shown
                        AppIcon {
                            id: appIcon
                            required property var modelData
                            anchors.verticalCenter: parent.verticalCenter
                            name: appIcon.modelData.cls
                            size: 16
                            tinted: !btn.active
                            // Above the button's own area: a click here focuses this app's window.
                            MouseArea {
                                anchors.fill: parent
                                z: 1
                                cursorShape: Qt.PointingHandCursor
                                // The focus with warps off for that one call: the cursor stays on the bar instead of
                                // jumping to the window's center (cursor.no_warps is false everywhere else).
                                onClicked: {
                                    strip.host.hideHint();
                                    strip.host.launch(["hyprctl", "eval", "hl.config({ cursor = { no_warps = true } }); hl.dispatch(hl.dsp.focus({ window = \"address:" + appIcon.modelData.address + "\" })); hl.config({ cursor = { no_warps = false } })"]);
                                }
                            }
                        }
                    }
                    Text {
                        visible: btn.apps.length > btn.shown.length
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+" + (btn.apps.length - btn.shown.length)
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontSmall
                    }
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

// The ADAPTIVE WORKSPACE RAIL: one monitor's workspaces as two-digit numbers under ONE sliding
// active pill. Three states by contrast (active, occupied, empty) and two marks, a new window and a
// request for attention, neither pulsing. The rail, its model (orphans of a gone secondary) and the
// 0.55 dispatch trap: docs/notes/desktop/bar.md
import QtQuick
import "root:/"

Item {
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
    implicitWidth: wsRow.implicitWidth
    implicitHeight: Theme.barControl

    // The ACTIVE workspace is ONE pill that eases to its button, so a switch reads as a move.
    Rectangle {
        id: ind
        visible: strip.act !== null
        x: strip.act ? strip.act.x : 0
        width: strip.act ? strip.act.width : 0
        height: Theme.barControl
        radius: Theme.radiusControl
        color: Theme.colWsActiveBg
        onVisibleChanged: if (visible)
            Qt.callLater(() => strip.placed = true)
        Behavior on x {
            enabled: strip.placed
            NumberAnimation {
                duration: Theme.motionNormal
                easing.type: Easing.OutCubic
            }
        }
        Behavior on width {
            enabled: strip.placed
            NumberAnimation {
                duration: Theme.motionNormal
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        id: wsRow
        spacing: Theme.sp1
        Repeater {
            id: wsRep
            model: strip.ids
            delegate: Rectangle {
                id: btn
                required property int modelData
                readonly property bool active: strip.host.wsActive[strip.monitor] === btn.modelData
                readonly property bool exists: strip.host.wsExist[btn.modelData] === true
                readonly property bool urgent: strip.host.wsUrgent[btn.modelData] === true
                readonly property bool activity: strip.host.wsActivity[btn.modelData] === true

                // ONE width for every number, from a template: "01" and "08" never differ.
                implicitWidth: Math.max(Theme.barControl, Math.ceil(tmNum.advanceWidth) + 2 * Theme.sp2)
                implicitHeight: Theme.barControl
                radius: Theme.radiusControl
                // Active, the button is see-through and the sliding pill shows under it.
                color: !btn.active && area.containsMouse ? Theme.colHoverFill : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.motionHover
                    }
                }

                Text {
                    id: num
                    anchors.centerIn: parent
                    text: strip.host.wsLabel(btn.modelData)
                    // Occupied reads clearly above empty; the active one sits dark on the blue pill.
                    color: btn.active ? Theme.colBgSolid : (btn.exists ? Theme.colText : Theme.colDim)
                    opacity: btn.active || btn.exists ? 1 : 0.7
                    // In step with the pill, so the number is never dark on dark while the pill is on its way.
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.motionNormal
                        }
                    }
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontBody
                    font.bold: btn.active || btn.exists
                }
                // Occupied and not active: a 2 px rule under the number, so the state is not color alone.
                Rectangle {
                    visible: btn.exists && !btn.active && !btn.activity && !btn.urgent
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    width: 8
                    height: 2
                    radius: 1
                    color: Theme.colDim
                }
                // The marks: a window opened here (yellow) or asked for attention (orange, larger). Steady,
                // never pulsing; visiting the workspace clears them.
                Rectangle {
                    visible: (btn.activity || btn.urgent) && !btn.active
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: btn.urgent ? 2 : 3
                    anchors.topMargin: btn.urgent ? 2 : 3
                    width: btn.urgent ? 7 : 5
                    height: width
                    radius: width / 2
                    color: btn.urgent ? Theme.colAlert : Theme.colWarn
                    border.color: Theme.colBgSolid
                    border.width: btn.urgent ? 1 : 0
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

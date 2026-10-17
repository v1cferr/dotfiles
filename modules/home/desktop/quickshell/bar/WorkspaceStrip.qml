// One monitor's workspaces: flat buttons under ONE sliding active pill, plus the activity badge.
// The model (orphans of a gone secondary) and the 0.55 dispatch trap: docs/notes/desktop/bar.md
import QtQuick
import "root:/"

Item {
    id: strip
    required property var host // the Bar's Scope: the workspace state lives there
    property string monitor: ""

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
                readonly property bool activity: strip.host.wsActivity[btn.modelData] === true

                implicitWidth: Math.max(Theme.barControl + 2, glyph.implicitWidth + 2 * Theme.sp2)
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
                    id: glyph
                    anchors.centerIn: parent
                    text: btn.active ? "󰮯" : strip.host.wsIcon(btn.modelData)
                    // A workspace with windows reads brighter than an empty one.
                    color: btn.active ? Theme.colBgSolid : (btn.exists ? Theme.colWsInactive : Theme.colDim)
                    // In step with the pill, so the glyph is never dark on dark while the pill is on its way.
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.motionNormal
                        }
                    }
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontLabel
                    font.bold: btn.active
                }
                // The badge: something opened or went urgent on that ws while I was on another. A status
                // pulse, so it stays on with motion off.
                Rectangle {
                    visible: btn.activity && !btn.active
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.rightMargin: 2
                    anchors.topMargin: 2
                    width: 7
                    height: 7
                    radius: 3.5
                    color: Theme.colPeach
                    border.color: Theme.colBgSolid
                    border.width: 1
                    SequentialAnimation on opacity {
                        running: btn.activity && !btn.active
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: 1
                            to: 0.35
                            duration: 700
                            easing.type: Easing.InOutQuad
                        }
                        NumberAnimation {
                            from: 0.35
                            to: 1
                            duration: 700
                            easing.type: Easing.InOutQuad
                        }
                    }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    // `hl.dsp.workspace` is a TABLE; what switches is focus (0.55's Lua dispatch).
                    onClicked: strip.host.launch(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = " + btn.modelData + " })"])
                }
            }
        }
    }
}

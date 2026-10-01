// The VPN ACTIONS popover (click): a row per VPN plus "Disconnect all". It replaced a loose rofi,
// and it shares the Bar's single source. Why click and not hover: docs/notes/desktop/bar.md
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"

PanelWindow {
    id: vpnPop
    required property var bar

    visible: bar.vpnPopVisible
    screen: bar.popScreen || bar.screenPrimary
    anchors {
        top: true
        left: true
    }
    margins {
        top: 4 // = Hyprland's gaps_out (the barExclusiveZone 30 is already discounted)
        left: bar.popLeft(vpnPop.implicitWidth)
    }
    exclusiveZone: 0
    implicitWidth: 268
    implicitHeight: card.implicitHeight
    color: "transparent"

    // It closes on its own when the mouse leaves, but NEVER in the middle of an action,
    // otherwise the panel evaporates exactly while you wait for the click's result.
    Timer {
        interval: 2500
        running: vpnPop.visible && !popHover.hovered && !vpnPop.bar.vpnBusy
        onTriggered: vpnPop.bar.vpnPopVisible = false
    }

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: col.implicitHeight + 24
        radius: 12
        color: Theme.colBg
        border.color: Theme.colBorder
        border.width: 1

        HoverHandler {
            id: popHover
        }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Text {
                text: "󰦝  VPN"
                color: Theme.colAccent
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.bold: true
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.colBorder
                opacity: 0.5
            }

            // It only shows up if the status-json comes back empty or unreadable, which normally never happens.
            Text {
                visible: (vpnPop.bar.vpnList || []).length === 0
                text: "no answer from `vpn status-json`"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 11
            }

            Repeater {
                model: vpnPop.bar.vpnList || []
                delegate: RowLayout {
                    id: row
                    required property var modelData
                    readonly property bool connected: row.modelData.connected === true
                    Layout.fillWidth: true
                    spacing: 9

                    Rectangle {
                        width: 9
                        height: 9
                        radius: 4.5
                        Layout.alignment: Qt.AlignVCenter
                        color: row.connected ? Theme.colGreen : Theme.colDim
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.hoverAnim
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "" + row.modelData.name
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }

                    Rectangle {
                        implicitWidth: btnLabel.implicitWidth + 20
                        implicitHeight: 24
                        radius: 7
                        color: btnArea.containsMouse ? (row.connected ? Theme.colHoverBgDanger : Theme.colHoverBgOk) : "transparent"
                        border.color: row.connected ? Theme.colRed : Theme.colGreen
                        border.width: 1
                        opacity: vpnPop.bar.vpnBusy ? 0.4 : 1
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.hoverAnim
                                easing.type: Easing.OutQuad
                            }
                        }

                        Text {
                            id: btnLabel
                            anchors.centerIn: parent
                            text: row.connected ? "Disconnect" : "Connect"
                            color: row.connected ? Theme.colRed : Theme.colGreen
                            font.family: Theme.uiFont
                            font.pixelSize: 11
                        }

                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !vpnPop.bar.vpnBusy
                            onClicked: vpnPop.bar.runVpn(row.connected ? "disconnect" : "connect", row.modelData.id)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.colBorder
                opacity: 0.5
                // it disappears when none is connected: a separator for nothing is noise
                visible: (vpnPop.bar.vpnList || []).some(v => v.connected === true)
            }

            // A shortcut for taking both down at once (the same as right-clicking the pill).
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 26
                radius: 7
                visible: (vpnPop.bar.vpnList || []).some(v => v.connected === true)
                color: allArea.containsMouse ? Theme.colMenuHoverBgDanger : "transparent"
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.hoverAnim
                        easing.type: Easing.OutQuad
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "󰗼  Disconnect all"
                    color: allArea.containsMouse ? Theme.colRed : Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.hoverAnim
                        }
                    }
                }

                MouseArea {
                    id: allArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !vpnPop.bar.vpnBusy
                    onClicked: vpnPop.bar.runVpn("disconnect", "all")
                }
            }

            Text {
                visible: vpnPop.bar.vpnBusy
                text: "running…"
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 10
                font.italic: true
            }
        }
    }
}

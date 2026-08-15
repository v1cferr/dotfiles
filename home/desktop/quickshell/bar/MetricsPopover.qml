// The metrics popover (temp / usage / network). The state lives in the Bar, through `bar`.
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"

PanelWindow {
    id: metricPop
    required property var bar
    visible: bar.metricPopVisible
    screen: bar.popScreen || bar.screenPrimary
    anchors {
        top: true
        left: true
    }
    margins {
        top: 4 // = Hyprland's gaps_out: it aligns the popover with the top of the windows (barExclusiveZone 30 already added)
        left: bar.popLeft(metricPop.implicitWidth)
    }
    exclusiveZone: 0
    implicitWidth: 300
    implicitHeight: 240
    color: "transparent"
    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#f21a1b26"
        border.color: "#414868"
        border.width: 1
        HoverHandler {
            onHoveredChanged: bar.metricPopHovered = hovered
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            Text {
                text: bar.metricShown === "temp" ? "Temperatures" : (bar.metricShown === "net" ? "Network" : "Usage")
                color: Theme.colAccent
                font.family: Theme.uiFont
                font.pixelSize: 14
                font.bold: true
            }
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#414868"
                opacity: 0.5
            }
            Repeater {
                model: bar.metricRows
                ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 3
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Text {
                            Layout.fillWidth: true
                            text: modelData.label
                            color: Theme.colText
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                        }
                        Text {
                            text: modelData.value
                            color: Theme.colText
                            font.family: Theme.uiFont
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                    Rectangle {
                        visible: modelData.frac !== undefined
                        Layout.fillWidth: true
                        implicitHeight: 5
                        radius: 2.5
                        color: "#33414868"
                        Rectangle {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width * (modelData.frac !== undefined ? modelData.frac : 0)
                            height: parent.height
                            radius: parent.radius
                            color: modelData.barColor !== undefined ? modelData.barColor : Theme.colAccent
                            Behavior on width {
                                NumberAnimation {
                                    duration: 300
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }
                }
            }
            Item {
                Layout.fillHeight: true
            }
        }
    }
}

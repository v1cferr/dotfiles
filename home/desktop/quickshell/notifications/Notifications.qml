// The notifications' UI: toasts (the main monitor's top right corner) plus the notification
// center (toggled by the bar's bell). It reads the Notifs.qml service. Tokyo Night style, aligned
// with the bar / OSD / panels.
// The card (NotifCard.qml) and the header's button (HeaderBtn.qml) are files of their own, since
// an inline component breaks the root's scope inside handlers on this Qt.
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "root:/"

Scope {
    id: root

    // ===== Toasts, the main monitor's top right =====
    PanelWindow {
        id: popupWin
        visible: Notifs.popups.length > 0
        screen: Theme.screenPrimary
        anchors {
            top: true
            right: true
        }
        margins {
            top: 8
            right: 8
        }
        exclusiveZone: 0
        color: "transparent"
        implicitWidth: 390
        implicitHeight: Math.max(1, popupCol.implicitHeight)

        ColumnLayout {
            id: popupCol
            anchors.fill: parent
            spacing: 8
            Repeater {
                model: Notifs.popups
                NotifCard {
                    required property var modelData
                    Layout.fillWidth: true
                    notif: modelData
                    isPopup: true
                }
            }
        }
    }

    // ===== The center: a panel at the TOP CENTER, fitted to the content (it grows with the
    // notifications up to a ceiling, then scrolls). Toggled by the bell. =====
    PanelWindow {
        id: centerWin
        visible: Notifs.centerVisible
        screen: Theme.screenPrimary
        // only `top` means the layer shell centers it horizontally
        anchors {
            top: true
        }
        margins {
            top: 8
        }
        exclusiveZone: 0
        color: "transparent"
        implicitWidth: 420
        implicitHeight: centerCard.implicitHeight

        // It disappears on its own after 5s; the counter pauses while the mouse is on the panel
        // (and restarts from zero when the mouse leaves).
        Timer {
            running: Notifs.centerVisible && !centerHover.hovered
            interval: 5000
            onTriggered: Notifs.centerVisible = false
        }

        Rectangle {
            id: centerCard
            anchors.fill: parent
            implicitHeight: centerCol.implicitHeight + 28
            radius: 14
            color: Theme.colBg
            border.color: Theme.colBorder
            border.width: 1

            HoverHandler {
                id: centerHover
            }

            ColumnLayout {
                id: centerCol
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // The header: the title plus the count badge plus the actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "󰂚"
                        color: Theme.colAccent
                        font.family: Theme.uiFont
                        font.pixelSize: 16
                    }
                    Text {
                        text: "Notifications"
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: 14
                        font.bold: true
                    }
                    Rectangle {
                        visible: Notifs.count > 0
                        implicitWidth: badge.implicitWidth + 12
                        implicitHeight: 18
                        radius: 9
                        color: Theme.colAccent
                        Text {
                            id: badge
                            anchors.centerIn: parent
                            text: "" + Notifs.count
                            color: "#1a1b26"
                            font.family: Theme.uiFont
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    HeaderBtn {
                        text: Notifs.dnd ? "󰂛 DND" : "󰂚 DND"
                        active: Notifs.dnd
                        onClicked: Notifs.toggleDnd()
                    }
                    HeaderBtn {
                        text: "󰎟 Clear"
                        enabled: Notifs.count > 0
                        onClicked: Notifs.clearAll()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.colBorder
                    opacity: 0.5
                }

                // The empty state, compact and centered
                ColumnLayout {
                    visible: Notifs.count === 0
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                    spacing: 6
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "󰂜"
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: 32
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "No notifications"
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }
                }

                // The list: it grows with the content up to 560px, then scrolls
                ListView {
                    visible: Notifs.count > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(contentHeight, 560)
                    clip: true
                    spacing: 8
                    model: Notifs.history
                    delegate: NotifCard {
                        required property var modelData
                        width: ListView.view.width
                        notif: modelData
                        isPopup: false
                    }
                }
            }
        }
    }
}

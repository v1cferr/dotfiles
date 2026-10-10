// Tor's state rows, shared by both VPN popovers: the system Tor and Bisq's own, no button. What
// each row detects and why Stack Wallet has none: docs/notes/desktop/bar.md
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: tor
    required property var bar
    // The click menu passes true: a Turn on/off button on the system row (the hover panel stays read-only).
    property bool actions: false

    Layout.fillWidth: true
    spacing: 8

    Repeater {
        model: [
            {
                name: "System Tor",
                system: true,
                on: tor.bar.torSystem,
                detail: tor.bar.torSystem ? "SOCKS :9050" : "off"
            },
            {
                name: "Bisq 2",
                system: false,
                on: tor.bar.torBisq,
                detail: tor.bar.torBisq ? "own Tor" : "closed"
            }
        ]
        delegate: RowLayout {
            id: torRow
            required property var modelData
            Layout.fillWidth: true
            spacing: 9

            Rectangle {
                width: 9
                height: 9
                radius: 4.5
                Layout.alignment: Qt.AlignVCenter
                color: torRow.modelData.on ? Theme.colLavender : Theme.colDim
            }
            Text {
                Layout.fillWidth: true
                text: torRow.modelData.name
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 12
            }
            Text {
                text: torRow.modelData.detail
                color: torRow.modelData.on ? Theme.colLavender : Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: 11
            }
            Rectangle {
                visible: tor.actions && torRow.modelData.system
                implicitWidth: torBtnLabel.implicitWidth + 20
                implicitHeight: 24
                radius: 7
                color: torBtnArea.containsMouse ? (torRow.modelData.on ? Theme.colHoverBgDanger : Theme.colHoverBgOk) : "transparent"
                border.color: torRow.modelData.on ? Theme.colRed : Theme.colGreen
                border.width: 1
                opacity: tor.bar.torBusy ? 0.4 : 1

                Text {
                    id: torBtnLabel
                    anchors.centerIn: parent
                    text: torRow.modelData.on ? "Turn off" : "Turn on"
                    color: torRow.modelData.on ? Theme.colRed : Theme.colGreen
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                }
                MouseArea {
                    id: torBtnArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    enabled: !tor.bar.torBusy
                    onClicked: tor.bar.runTor(torRow.modelData.on ? "stop" : "start")
                }
            }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.maximumWidth: 330
        wrapMode: Text.WordWrap
        text: "Only apps pointed at Tor use it; the rest of this machine is not on Tor. Stack Wallet's Tor is inside the app: check its own indicator."
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 10
    }
}

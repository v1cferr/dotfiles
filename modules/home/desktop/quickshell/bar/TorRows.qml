// Tor's state rows, shared by both VPN popovers: the system Tor and Bisq's own, no button. What
// each row detects and why Stack Wallet has none: docs/notes/desktop/bar.md
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: tor
    required property var bar

    Layout.fillWidth: true
    spacing: 8

    Repeater {
        model: [
            {
                name: "System Tor",
                on: tor.bar.torSystem,
                detail: tor.bar.torSystem ? "SOCKS :9050" : "off"
            },
            {
                name: "Bisq 2",
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

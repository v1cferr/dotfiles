// The VPN page: each tunnel with what it is doing and the one action that fits, then Tor. Every
// action goes through the `vpn` CLI the bar already drives. docs/notes/desktop/control-center.md#vpn
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/bar"
import "root:/widgets"

ColumnLayout {
    id: page
    required property var host // the Bar's Scope: the VPN state and its actions
    spacing: Theme.sp2

    readonly property var words: ({
            connected: "Connected",
            connecting: "Connecting…",
            disconnecting: "Disconnecting…",
            disconnected: "Off",
            error: "Did not connect",
            unknown: "Unknown"
        })
    function tone(state) {
        return state === "connected" ? Theme.colOk : (state === "error" ? Theme.colCrit : (state === "disconnected" || state === "unknown" ? Theme.colDim : Theme.colWarn));
    }

    Text {
        visible: page.host.vpnList.length === 0
        text: "The vpn command did not answer"
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
    }
    Repeater {
        model: page.host.vpnList
        Rectangle {
            id: row
            required property var modelData
            readonly property string state: page.host.vpnState(row.modelData)
            readonly property bool busy: row.state === "connecting" || row.state === "disconnecting"
            Layout.fillWidth: true
            implicitHeight: Theme.sp6 * 2 + Theme.sp1
            radius: Theme.radiusSurface
            color: Qt.alpha(Theme.colText, 0.04)
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.sp3
                anchors.rightMargin: Theme.sp2
                spacing: Theme.sp2
                Rectangle {
                    implicitWidth: Theme.sp2
                    implicitHeight: Theme.sp2
                    radius: Theme.sp1
                    color: page.tone(row.state)
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: "" + row.modelData.name
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontBody
                        font.weight: Theme.weightStrong
                    }
                    Text {
                        Layout.fillWidth: true
                        // An error says WHY, in the CLI's own words.
                        text: row.state === "error" ? (page.host.vpnError[row.modelData.id] || page.words.error) : page.words[row.state]
                        color: row.state === "error" ? Theme.colCrit : Theme.colSubtext
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontSmall
                        elide: Text.ElideRight
                    }
                }
                Rectangle {
                    id: act
                    readonly property bool down: row.modelData.connected || row.state === "connecting"
                    implicitWidth: actLabel.implicitWidth + 2 * Theme.sp3
                    implicitHeight: Theme.barControl
                    radius: Theme.radiusControl
                    opacity: page.host.vpnBusy ? Theme.opacityDisabled : 1
                    color: actArea.pressed ? Theme.colPressFill : (actArea.containsMouse ? Theme.colHoverFill : Theme.colCellHoverFill)
                    Accessible.role: Accessible.Button
                    Accessible.name: actLabel.text + " " + row.modelData.name
                    Text {
                        id: actLabel
                        anchors.centerIn: parent
                        text: act.down ? "Disconnect" : (row.state === "error" ? "Try again" : "Connect")
                        color: Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontSmall
                    }
                    MouseArea {
                        id: actArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !page.host.vpnBusy
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.host.runVpn(act.down ? "disconnect" : "connect", row.modelData.id)
                    }
                    KeyTarget {
                        activeFocusOnTab: !page.host.vpnBusy
                        onActivated: page.host.runVpn(act.down ? "disconnect" : "connect", row.modelData.id)
                    }
                }
            }
        }
    }
    Text {
        Layout.topMargin: Theme.sp1
        text: "TOR"
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontMicro
        font.letterSpacing: 1
    }
    TorRows {
        Layout.fillWidth: true
        bar: page.host
        actions: true
    }
}

// The NixOS Center's BOOT section: what boot-trust could PROVE about this boot, read when the panel
// opens (no polling). The math is data/BootTrustMath.qml. docs/notes/desktop/nixos-center.md
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/data"

ColumnLayout {
    id: boot
    spacing: Theme.sp2

    property var record: null
    function refresh() {
        file.reload();
    }
    BootTrustMath {
        id: math
    }
    readonly property var cards: math.cards(boot.record)
    function tone(t) {
        return t === "ok" ? Theme.colOk : t === "warn" ? Theme.colWarn : t === "crit" ? Theme.colCrit : Theme.colUnknown;
    }

    // Written by a root oneshot at boot and after each install (modules/nixos/core/boot-trust.nix).
    FileView {
        id: file
        path: "/run/boot-trust.json"
        onLoaded: {
            try {
                boot.record = JSON.parse(file.text());
            } catch (e) {
                boot.record = null;
            }
        }
        onLoadFailed: boot.record = null
    }

    Text {
        text: "BOOT"
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontSmall
        font.letterSpacing: 1
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp2
        Repeater {
            model: boot.cards
            delegate: Rectangle {
                id: bootCard
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                implicitHeight: col.implicitHeight + 2 * Theme.sp2
                radius: Theme.radiusControl
                color: Qt.alpha(Theme.colText, 0.04)
                Accessible.role: Accessible.StaticText
                Accessible.name: bootCard.modelData.label + " " + bootCard.modelData.value + ", " + bootCard.modelData.caption
                ColumnLayout {
                    id: col
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Theme.sp2
                    spacing: 0
                    Text {
                        text: bootCard.modelData.label
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontMicro
                        font.letterSpacing: 1
                    }
                    Text {
                        text: bootCard.modelData.value
                        color: boot.tone(bootCard.modelData.tone)
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontTitle
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: bootCard.modelData.caption
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontMicro
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}

// The app vault's password card: centered on the FOCUSED monitor over a dim scrim, the keyboard
// exclusive while it is up. It reuses the lock's PAM conversation (lock/Auth.qml) on its OWN
// service, quickshell-vault, whose password is not the login one. Esc cancels and the apps stay hidden;
// three misses in a row wait 30 s. The state is Vault.qml. docs/notes/desktop/vault.md
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import "root:/"
import "root:/lock"

Scope {
    id: prompt

    property int misses: 0 // in a row, for this card; Auth.fails counts the whole session
    property double coolUntil: 0
    property double now: Date.now()
    readonly property int coolLeft: Math.max(0, Math.ceil((prompt.coolUntil - prompt.now) / 1000))

    Auth {
        id: auth
        service: "quickshell-vault"
        onUnlocked: {
            prompt.misses = 0;
            Vault.release();
        }
        onFailed: {
            prompt.misses += 1;
            if (prompt.misses >= 3) {
                prompt.misses = 0;
                prompt.coolUntil = Date.now() + 30000;
            }
        }
    }

    // A fresh card starts empty: nothing typed for one app carries into the next ask.
    Connections {
        target: Vault
        function onActiveChanged() {
            if (!Vault.active)
                auth.clear();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: prompt.coolLeft > 0
        onTriggered: prompt.now = Date.now()
        onRunningChanged: prompt.now = Date.now()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: Vault.active && Hyprland.focusedMonitor?.name === modelData.name
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "#99000000"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "vault"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            // A click outside the card is a cancel, like Esc.
            MouseArea {
                anchors.fill: parent
                onClicked: Vault.cancel()
            }

            Rectangle {
                id: card
                anchors.centerIn: parent
                width: 380
                height: column.implicitHeight + 2 * Theme.sp6
                radius: Theme.radiusSurface + Theme.sp2
                color: Theme.colBgSolid
                border.color: Theme.colBorder
                border.width: Theme.hairline

                // Swallows clicks so the scrim's cancel only hears the outside.
                MouseArea {
                    anchors.fill: parent
                }

                Column {
                    id: column
                    anchors.centerIn: parent
                    width: parent.width - 2 * Theme.sp6
                    spacing: Theme.sp4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "lock"
                        color: Theme.colAccent
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 40
                    }

                    // One chip per app the card unlocks.
                    Flow {
                        width: parent.width
                        spacing: Theme.sp2
                        layoutDirection: Qt.LeftToRight
                        Repeater {
                            model: Vault.apps
                            Rectangle {
                                required property string modelData
                                width: chip.implicitWidth + 2 * Theme.sp3
                                height: 32
                                radius: Theme.radiusControl
                                color: Theme.colTrack
                                Row {
                                    id: chip
                                    anchors.centerIn: parent
                                    spacing: Theme.sp2
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Vault.icons[modelData] || "apps"
                                        color: Theme.colSubtext
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 18
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: Vault.names[modelData] || modelData
                                        color: Theme.colText
                                        font.family: Theme.uiFont
                                        font.pixelSize: 14
                                    }
                                }
                            }
                        }
                    }

                    // The field: dots as you type, then the state in words.
                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: Theme.radiusControl
                        color: Theme.colTrack
                        border.width: Theme.hairline
                        border.color: auth.fails > 0 && auth.buffer === "" ? Theme.colRed : Theme.colHoverBorder

                        Text {
                            anchors.centerIn: parent
                            text: prompt.coolLeft > 0 ? `aguarde ${prompt.coolLeft} s` : auth.buffer.length ? "•".repeat(Math.min(24, auth.buffer.length)) : auth.busy ? "verificando…" : prompt.misses > 0 ? "senha incorreta" : "senha"
                            color: auth.buffer.length ? Theme.colText : prompt.misses > 0 || prompt.coolLeft > 0 ? Theme.colRed : Theme.colDim
                            font.family: Theme.uiFont
                            font.pixelSize: auth.buffer.length ? 20 : 15
                            font.letterSpacing: auth.buffer.length ? 4 : 0
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: "Enter desbloqueia · Esc cancela"
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: 12
                    }
                }
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => {
                    event.accepted = true;
                    if (event.key === Qt.Key_Escape) {
                        Vault.cancel();
                        return;
                    }
                    if (prompt.coolLeft > 0)
                        return; // the wait swallows every key but Esc
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                        auth.submit();
                    else if (event.key === Qt.Key_Backspace)
                        (event.modifiers & Qt.ControlModifier) ? auth.clear() : auth.erase();
                    else if (event.text >= " ")
                        auth.type(event.text); // printable only: Tab and friends stay out of the password
                }
            }
        }
    }
}

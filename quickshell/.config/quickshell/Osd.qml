// OSD (toast) de volume + mute de microfone + brilho (gamma do hyprsunset),
// estilo Tokyo Night. Volume/mic aparecem reagindo ao Pipewire; brilho é
// empurrado por IPC (qs ipc call osd brightness <valor> <max>) pelas teclas
// XF86MonBrightness. Some sozinho após ~1.5s. Fixado bottom-center no DP-1.
//
// Brilho aqui = gamma do hyprsunset (este desktop não tem backlight real;
// brightnessctl/ddcutil ausentes). gamma 100 = normal, vai até max-gamma (150).
//
// Nota: "Translate ID error: -1 (default-nodes-api)" no log é ruído nativo do
// libpipewire, não deste QML.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // "volume" | "mic" | "brightness" — o que disparou o OSD por último
    property string mode: "volume"
    property bool shown: false

    // Brilho (empurrado via IPC pelas teclas de brilho)
    property int brightnessValue: 100
    property int brightnessMax: 150

    // Trava anti-flash (boot) + anti-troca-de-device pro caminho reativo do
    // Pipewire. Cada evento de settling re-adia o arme; o show real é coalescido
    // num Timer(0) que só mostra se "armed" continuar true no próximo ciclo do
    // event loop. (O brilho via IPC NÃO passa por essa trava — é ação explícita.)
    property bool armed: false

    PwObjectTracker {
        objects: {
            const arr = [];
            if (Pipewire.defaultAudioSink)
                arr.push(Pipewire.defaultAudioSink);
            if (Pipewire.defaultAudioSource)
                arr.push(Pipewire.defaultAudioSource);
            return arr;
        }
    }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property real volume: (sink && sink.audio) ? sink.audio.volume : 0
    readonly property bool sinkMuted: (sink && sink.audio) ? sink.audio.muted : false
    readonly property bool micMuted: (source && source.audio) ? source.audio.muted : false

    onVolumeChanged: root.trigger("volume")
    onSinkMutedChanged: root.trigger("volume")
    onMicMutedChanged: root.trigger("mic")

    function deferArm() {
        root.armed = false;
        armTimer.restart();
    }

    function trigger(m) {
        root.mode = m;
        showTimer.restart();
    }

    // Mostra direto (sem a trava armed): usado pelo brilho via IPC.
    function showNow(m) {
        root.mode = m;
        root.shown = true;
        hideTimer.restart();
    }

    function volIcon() {
        if (root.sinkMuted || root.volume <= 0.0)
            return "󰝟";
        if (root.volume <= 0.33)
            return "󰕿";
        if (root.volume <= 0.66)
            return "󰖀";
        return "󰕾";
    }

    function brightIcon() {
        const frac = root.brightnessMax > 0 ? root.brightnessValue / root.brightnessMax : 0;
        if (frac <= 0.33)
            return "󰃞";
        if (frac <= 0.66)
            return "󰃟";
        return "󰃠";
    }

    // Brilho empurrado pelas teclas XF86MonBrightness via:
    //   qs ipc call osd brightness <valor> <max>
    IpcHandler {
        target: "osd"

        function brightness(value: int, max: int): void {
            root.brightnessMax = max > 0 ? max : 150;
            root.brightnessValue = value;
            root.showNow("brightness");
        }
    }

    Connections {
        target: Pipewire
        function onDefaultAudioSinkChanged() {
            root.deferArm();
        }
        function onDefaultAudioSourceChanged() {
            root.deferArm();
        }
        function onReadyChanged() {
            if (Pipewire.ready)
                root.deferArm();
        }
    }
    Component.onCompleted: root.deferArm()

    Timer {
        id: armTimer
        interval: 500
        onTriggered: root.armed = true
    }

    Timer {
        id: showTimer
        interval: 0
        onTriggered: {
            if (!root.armed)
                return;
            root.shown = true;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    PanelWindow {
        id: osd
        visible: root.shown

        screen: Theme.screenDP1

        anchors {
            bottom: true
        }
        margins {
            bottom: 90
        }

        exclusiveZone: 0
        implicitWidth: 300
        implicitHeight: 64
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Theme.colBg
            border.color: Theme.colBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 14

                // Ícone do modo atual. Sem font.family (mesma fallback Nerd do shell.qml).
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.mode === "mic" ? (root.micMuted ? "󰍭" : "󰍬") : root.mode === "brightness" ? root.brightIcon() : root.volIcon()
                    color: ((root.mode === "mic" && root.micMuted) || (root.mode === "volume" && root.sinkMuted)) ? Theme.colRed : Theme.colAccent
                    font.pixelSize: 26
                }

                // Modo VOLUME: barra + porcentagem
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.mode === "volume"
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        height: 8
                        radius: 4
                        color: Theme.colTrack

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.volume))
                            height: parent.height
                            radius: 4
                            color: root.sinkMuted ? Theme.colDim : Theme.colAccent
                            Behavior on width {
                                NumberAnimation {
                                    duration: 90
                                }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 46
                        horizontalAlignment: Text.AlignRight
                        text: root.sinkMuted ? "mudo" : Math.round(root.volume * 100) + "%"
                        color: Theme.colText
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                // Modo BRILHO (gamma do hyprsunset): barra + valor
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.mode === "brightness"
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        height: 8
                        radius: 4
                        color: Theme.colTrack

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.brightnessMax > 0 ? root.brightnessValue / root.brightnessMax : 0))
                            height: parent.height
                            radius: 4
                            color: Theme.colAccent
                            Behavior on width {
                                NumberAnimation {
                                    duration: 90
                                }
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.preferredWidth: 46
                        horizontalAlignment: Text.AlignRight
                        text: root.brightnessValue + "%"
                        color: Theme.colText
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                // Modo MIC: rótulo de estado
                Text {
                    Layout.fillWidth: true
                    visible: root.mode === "mic"
                    text: root.micMuted ? "Microfone mudo" : "Microfone ativo"
                    color: root.micMuted ? Theme.colRed : Theme.colText
                    font.pixelSize: 15
                    font.bold: true
                }
            }
        }
    }
}

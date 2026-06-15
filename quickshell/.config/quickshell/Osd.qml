// OSD (toast) de volume + mute de microfone, estilo Tokyo Night.
// Aparece ao mudar volume/mute do sink padrão ou o mute do microfone e some
// sozinho após ~1.5s. Usa o serviço nativo Quickshell.Services.Pipewire.
// Fixado bottom-center no DP-1 (nunca na TV HDMI-A-1).
//
// Brilho NÃO está aqui: este desktop não tem backlight (sem brightnessctl/ddcutil).
// O componente foi desenhado pra ganhar um terceiro "mode" depois.
//
// Nota sobre "Translate ID error: -1 (default-nodes-api)" no log: é ruído nativo
// do libpipewire quando o nó default ainda não resolveu; não é deste QML.
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // Paleta Tokyo Night (mesma da Waybar / shell.qml)
    readonly property color colBg: "#f21a1b26"
    readonly property color colBorder: "#414868"
    readonly property color colText: "#c0caf5"
    readonly property color colDim: "#565f89"
    readonly property color colAccent: "#7aa2f7"
    readonly property color colRed: "#f38ba8"
    readonly property color colTrack: "#283041"

    // "volume" ou "mic" — o que disparou o OSD por último
    property string mode: "volume"
    property bool shown: false

    // Trava anti-flash (boot) + anti-troca-de-device. Cada evento de settling
    // (boot, ready, troca de saída/headphone) re-adia o arme. O show real é
    // coalescido num Timer(0) que só mostra se "armed" continuar true no próximo
    // ciclo do event loop — ou seja, DEPOIS de todos os handlers síncronos do
    // mesmo sinal. Assim uma troca de device (que chama deferArm() e zera armed
    // no mesmo ciclo) nunca vaza um OSD, independente da ordem dos sinais do QML.
    property bool armed: false

    // Mantém sink e source "vivos" pra que volume/muted atualizem em tempo real.
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

    // Desarma já (suprime o disparo em voo) e re-arma 500ms após o ÚLTIMO settling.
    function deferArm() {
        root.armed = false;
        armTimer.restart();
    }

    function trigger(m) {
        root.mode = m;
        showTimer.restart(); // coalescido: decide no próximo ciclo do loop
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

        // Fixa no DP-1. Sem DP-1 presente -> screen null -> janela não mapeia
        // (garante que NUNCA aparece na TV HDMI-A-1).
        screen: {
            const screens = Quickshell.screens;
            for (let i = 0; i < screens.length; i++)
                if (screens[i].name === "DP-1")
                    return screens[i];
            return null;
        }

        // bottom-center: ancorar só na borda de baixo centraliza na horizontal.
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
            color: root.colBg
            border.color: root.colBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 14

                // Ícone (volume por nível/mute, ou microfone). Sem font.family
                // explícita — mesma fallback Nerd que o shell.qml usa no 󰦝.
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.mode === "mic" ? (root.micMuted ? "󰍭" : "󰍬") : root.volIcon()
                    color: (root.mode === "mic" && root.micMuted) || (root.mode === "volume" && root.sinkMuted) ? root.colRed : root.colAccent
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
                        color: root.colTrack

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.volume))
                            height: parent.height
                            radius: 4
                            color: root.sinkMuted ? root.colDim : root.colAccent
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
                        color: root.colText
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                // Modo MIC: rótulo de estado
                Text {
                    Layout.fillWidth: true
                    visible: root.mode === "mic"
                    text: root.micMuted ? "Microfone mudo" : "Microfone ativo"
                    color: root.micMuted ? root.colRed : root.colText
                    font.pixelSize: 15
                    font.bold: true
                }
            }
        }
    }
}

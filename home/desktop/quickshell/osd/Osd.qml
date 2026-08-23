// The OSD for volume, mic mute, brightness (= hyprsunset's gamma, since there is no backlight) and
// the mouse DPI. Volume/mic react to Pipewire; brightness and DPI are PUSHED through IPC.
// docs/notes/desktop/quickshell.md
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "root:/"

Scope {
    id: root

    // "volume" | "mic" | "brightness" | "dpi": what fired the OSD last
    property string mode: "volume"
    property bool shown: false

    // Brightness (pushed through IPC by the brightness keys)
    property int brightnessValue: 100
    property int brightnessMax: 150

    // Mouse DPI (pushed through IPC by razer-dpi, which watches the mouse's ONBOARD button)
    property int dpiValue: 0

    // An anti-flash lock for Pipewire's reactive path: every settling event pushes the arming back and
    // a Timer(0) coalesces the show. Brightness through IPC skips it, being an explicit action.
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

    // It shows directly (with no armed lock): used by brightness through IPC.
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

    // Pushed in: `qs ipc call osd brightness <value> <max>` by the XF86MonBrightness keys, and
    // `qs ipc call osd dpi <value>` by the razer-dpi watcher (home/services/razer-dpi.nix).
    IpcHandler {
        target: "osd"

        function brightness(value: int, max: int): void {
            root.brightnessMax = max > 0 ? max : 150;
            root.brightnessValue = value;
            root.showNow("brightness");
        }

        function dpi(value: int): void {
            root.dpiValue = value;
            root.showNow("dpi");
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

        screen: Theme.screenPrimary

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

                // The current mode's icon. With no font.family (the same Nerd fallback as shell.qml).
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.mode !== "dpi"
                    text: root.mode === "mic" ? (root.micMuted ? "󰍭" : "󰍬") : root.mode === "brightness" ? root.brightIcon() : root.volIcon()
                    color: ((root.mode === "mic" && root.micMuted) || (root.mode === "volume" && root.sinkMuted)) ? Theme.colRed : Theme.colAccent
                    font.pixelSize: 26
                }

                // DPI mode: the Razer mark itself, since no Nerd Font ships one and a generic mouse
                // glyph would say less than the logo of the thing that actually changed.
                Image {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 26
                    visible: root.mode === "dpi"
                    source: "root:/assets/razer.svg"
                    sourceSize: Qt.size(26, 26) // rasterize AT the drawn size, or the SVG comes out soft
                    fillMode: Image.PreserveAspectFit
                }

                // VOLUME mode: a bar plus a percentage
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
                        text: root.sinkMuted ? "muted" : Math.round(root.volume * 100) + "%"
                        color: Theme.colText
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                // BRIGHTNESS mode (hyprsunset's gamma): a bar plus the value
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

                // MIC mode: a state label
                Text {
                    Layout.fillWidth: true
                    visible: root.mode === "mic"
                    text: root.micMuted ? "Microphone muted" : "Microphone live"
                    color: root.micMuted ? Theme.colRed : Theme.colText
                    font.pixelSize: 15
                    font.bold: true
                }

                // DPI mode: the value alone. No bar, because the stages live in the mouse's ONBOARD
                // memory, so there is no range to draw a fraction against: docs/notes/hardware/razer.md
                Text {
                    Layout.fillWidth: true
                    visible: root.mode === "dpi"
                    text: root.dpiValue + " DPI"
                    color: Theme.colText
                    font.pixelSize: 15
                    font.bold: true
                }
            }
        }
    }
}

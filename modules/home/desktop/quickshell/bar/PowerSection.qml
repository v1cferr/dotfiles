// The NixOS Center's POWER section: the ppd profile (Balanced/Gaming/Eco), what its last apply did,
// and the memory and GPU readings behind it. The rules: docs/notes/desktop/nixos-center.md
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

ColumnLayout {
    id: power
    required property var bar
    spacing: Theme.sp2

    // ── The profile: ppd is the only owner, this only asks it (polkit lets the active session) ──
    readonly property var profiles: [
        {
            key: PowerProfile.Balanced,
            label: "Balanced",
            icon: "󰾅",
            name: "Balanced: the default"
        },
        {
            key: PowerProfile.Performance,
            label: "Gaming",
            icon: "󰊴",
            name: "Gaming: CPU performance, SignalSift paused, idle models unloaded"
        },
        {
            key: PowerProfile.PowerSaver,
            label: "Eco",
            icon: "󰌪",
            name: "Eco: CPU power saving, SignalSift idle, idle models unloaded"
        }
    ]
    property int requested: -1
    property string error: ""
    function pick(p) {
        power.error = "";
        power.requested = p.key;
        PowerProfiles.profile = p.key;
        verify.restart();
    }
    // Real feedback: the switch only counts once ppd reports it back.
    Timer {
        id: verify
        interval: 3000
        onTriggered: {
            if (PowerProfiles.profile !== power.requested)
                power.error = "ppd did not switch (daemon down, or polkit refused)";
            power.requested = -1;
        }
    }
    readonly property var hold: PowerProfiles.holds.length > 0 ? PowerProfiles.holds[0] : null

    // ── What the last apply did: power-profile-sync's state file, read on open and after a switch ──
    property var state: null
    function refresh() {
        stateFile.reload();
    }
    FileView {
        id: stateFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/power-profile.json"
        onLoaded: {
            try {
                power.state = JSON.parse(stateFile.text());
            } catch (e) {
                power.state = null;
            }
        }
        onLoadFailed: power.state = null
    }
    Connections {
        target: PowerProfiles
        function onProfileChanged() {
            settle.restart();
        }
    }
    Timer {
        id: settle
        interval: 1500 // the apply runs after ppd's signal: SignalSift answers in well under that
        onTriggered: power.refresh()
    }
    // No state file means the sync never ran: ppd is not up yet (before the switch) or the unit died.
    readonly property bool live: power.state !== null
    readonly property bool applyFailed: power.live && ((power.state.signalsiftResult || "").indexOf("failed") === 0 || (power.state.ollama || "").indexOf("failed") === 0)
    readonly property string status: {
        if (power.error !== "")
            return power.error;
        if (!power.live)
            return "power-profiles-daemon not running";
        const s = power.state;
        const ss = s.signalsiftResult === "ok" ? s.signalsift : (s.signalsiftResult === "off" ? "off" : s.signalsiftResult);
        return "SignalSift " + ss + " · Ollama " + s.ollama;
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp2
        Text {
            text: "POWER"
            color: Theme.colDim
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
            font.letterSpacing: 1
        }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: power.status
            color: (power.error !== "" || power.applyFailed) ? Theme.colCrit : (power.live ? Theme.colSubtext : Theme.colUnknown)
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
            elide: Text.ElideLeft
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp1
        Repeater {
            model: power.profiles
            delegate: Rectangle {
                id: prof
                required property var modelData
                readonly property bool current: power.live && PowerProfiles.profile === prof.modelData.key
                readonly property bool pending: power.requested === prof.modelData.key
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                implicitHeight: 44
                radius: Theme.radiusControl
                enabled: power.live
                opacity: power.live ? 1 : Theme.opacityDisabled
                color: prof.current ? Qt.alpha(Theme.colAccent, 0.18) : (profArea.containsMouse ? Theme.colHoverFill : "transparent")
                border.width: prof.current || prof.pending ? 1 : 0
                border.color: Theme.colAccent
                Behavior on color {
                    ColorAnimation {
                        duration: 140
                    }
                }
                Accessible.role: Accessible.Button
                Accessible.name: prof.modelData.name + (prof.current ? ", active" : "")
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: prof.modelData.icon
                        color: prof.current ? Theme.colAccent : Theme.colText
                        font.family: Theme.uiFont
                        font.pixelSize: 16
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: prof.modelData.label
                        color: prof.current ? Theme.colText : Theme.colSubtext
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontSmall
                    }
                }
                MouseArea {
                    id: profArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: power.pick(prof.modelData)
                }
                KeyTarget {
                    onActivated: power.pick(prof.modelData)
                }
            }
        }
    }

    // A hold (GameMode) overrides the pick until it ends; ppd then returns to the picked profile.
    Text {
        visible: power.live && power.hold !== null
        Layout.fillWidth: true
        text: power.hold ? "Held at " + PowerProfile.toString(power.hold.profile) + " by " + (power.hold.reason || power.hold.applicationId) + ", until it ends" : ""
        color: Theme.colWarn
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontMicro
        elide: Text.ElideRight
    }

    // ── The readings: all from the bar's own 2 s snapshot, no read of their own ──
    readonly property var cards: {
        const b = power.bar;
        const ratio = b.zramUsed > 0 ? (b.zramOrig / b.zramUsed).toFixed(1) + "x" : "";
        return [
            {
                label: "AVAILABLE",
                value: b.memTotal > 0 ? b.fmtBytes(b.memAvail) : "n/a",
                caption: "RAM",
                tone: Theme.colText
            },
            {
                label: "ZRAM",
                value: b.fmtBytes(b.zramOrig),
                caption: b.zramUsed > 0 ? "in " + b.fmtBytes(b.zramUsed) + " · " + ratio : "empty",
                tone: Theme.colText
            },
            {
                label: "NVME SWAP",
                value: b.fmtBytes(b.diskSwapUsed),
                caption: "the fallback",
                tone: Theme.colText
            },
            {
                label: "PRESSURE",
                value: b.psiMem.toFixed(1) + "%",
                caption: "memory, full",
                tone: b.psiMem >= 30 ? Theme.colCrit : (b.psiMem >= 10 ? Theme.colWarn : Theme.colText)
            },
            {
                label: "GPU BOARD",
                value: b.gpuWatts > 0 ? Math.round(b.gpuWatts) + " W" : "n/a",
                caption: b.gpuWatts > 0 ? "xe sensor, not the wall" : "no sensor",
                tone: b.gpuWatts > 0 ? Theme.colText : Theme.colUnknown
            }
        ];
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp2
        Repeater {
            model: power.cards
            delegate: Rectangle {
                id: card
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                implicitHeight: cardCol.implicitHeight + 2 * Theme.sp2
                radius: Theme.radiusControl
                color: Qt.alpha(Theme.colText, 0.04)
                Accessible.role: Accessible.StaticText
                Accessible.name: card.modelData.label + " " + card.modelData.value + ", " + card.modelData.caption
                ColumnLayout {
                    id: cardCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Theme.sp2
                    spacing: 0
                    Text {
                        text: card.modelData.label
                        color: Theme.colDim
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontMicro
                        font.letterSpacing: 1
                    }
                    Text {
                        Layout.fillWidth: true
                        text: card.modelData.value
                        color: card.modelData.tone
                        font.family: Theme.uiFont
                        font.pixelSize: Theme.fontBody
                        font.bold: true
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: card.modelData.caption
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

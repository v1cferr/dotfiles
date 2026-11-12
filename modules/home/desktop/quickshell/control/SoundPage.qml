// The Sound page: where the sound goes out and comes in, the microphone, and each app's own level.
// Pipewire binds a node's audio only while something tracks it, so the lists are tracked only
// while this page is the one on screen. docs/notes/desktop/control-center.md#sound
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

ColumnLayout {
    id: page
    property bool active: false
    signal leave(var command) // a fuller tool takes over: the panel closes and runs it
    spacing: Theme.sp2

    readonly property var nodes: page.active && Pipewire.nodes ? Pipewire.nodes.values : []
    readonly property var outputs: page.nodes.filter(n => n.audio && !n.isStream && n.isSink)
    readonly property var inputs: page.nodes.filter(n => n.audio && !n.isStream && !n.isSink)
    readonly property var apps: page.nodes.filter(n => n.audio && n.isStream && !n.isSink)
    PwObjectTracker {
        objects: page.apps
    }
    function label(n) {
        return n.description || n.nickname || n.name || "";
    }

    component Heading: Text {
        Layout.leftMargin: Theme.sp2
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontMicro
        font.letterSpacing: 1
    }
    // A device to pick: the one in use carries the check.
    component DeviceRow: Rectangle {
        id: dev
        property string text: ""
        property bool current: false
        signal picked
        Layout.fillWidth: true
        implicitHeight: Theme.barControl
        radius: Theme.radiusControl
        color: devArea.pressed ? Theme.colPressFill : (devArea.containsMouse ? Theme.colHoverFill : "transparent")
        Accessible.role: Accessible.RadioButton
        Accessible.name: dev.text
        Accessible.checked: dev.current
        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: Theme.sp2
            width: parent.width - 2 * Theme.sp2 - Theme.iconSymbol
            text: dev.text
            color: dev.current ? Theme.colText : Theme.colSubtext
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontBody
            elide: Text.ElideRight
        }
        Text {
            visible: dev.current
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.sp2
            text: "check"
            color: Theme.colAccent
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconBar
            font.variableAxes: Theme.iconAxes
        }
        MouseArea {
            id: devArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: dev.picked()
        }
        KeyTarget {
            onActivated: dev.picked()
        }
    }

    Heading {
        text: "OUTPUT"
    }
    Repeater {
        model: page.outputs
        DeviceRow {
            required property var modelData
            text: page.label(modelData)
            current: modelData === Audio.sink
            onPicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }

    Heading {
        Layout.topMargin: Theme.sp1
        text: "INPUT"
    }
    Text {
        visible: page.inputs.length === 0
        text: "No microphone"
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontBody
    }
    Repeater {
        model: page.inputs
        DeviceRow {
            required property var modelData
            text: page.label(modelData)
            current: modelData === Audio.source
            onPicked: Pipewire.preferredDefaultAudioSource = modelData
        }
    }
    Slider {
        visible: !!Audio.source
        Layout.fillWidth: true
        name: "Microphone"
        icon: Audio.micMuted ? "mic_off" : "mic"
        value: Audio.micVolume
        dimmed: Audio.micMuted
        onMoved: v => Audio.setMicVolume(v)
        onIconClicked: Audio.toggleMic()
    }

    Heading {
        visible: page.apps.length > 0
        Layout.topMargin: Theme.sp1
        text: "APPS"
    }
    Repeater {
        model: page.apps
        ColumnLayout {
            id: app
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.sp1
            Text {
                Layout.fillWidth: true
                text: (app.modelData.properties && app.modelData.properties["application.name"]) || page.label(app.modelData)
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
            Slider {
                Layout.fillWidth: true
                name: page.label(app.modelData)
                icon: app.modelData.audio.muted ? "volume_off" : "volume_up"
                value: app.modelData.audio.volume
                dimmed: app.modelData.audio.muted
                onMoved: v => app.modelData.audio.volume = v
                onIconClicked: app.modelData.audio.muted = !app.modelData.audio.muted
            }
        }
    }

    Hairline {}
    PageLink {
        label: "Mixer"
        onClicked: page.leave(["pavucontrol"])
    }
}

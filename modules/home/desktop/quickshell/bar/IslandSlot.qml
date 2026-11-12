// The ISLAND's capsule: it grows out from behind the logo, the same on both sides, and says one
// thing at a time. The logo is not in it and never moves; Island.qml decides what it shows.
// docs/notes/desktop/island.md
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "root:/"

Item {
    id: isle
    required property var host // the Bar's Scope: where a click on the capsule leads
    property var barWindow: null

    readonly property var ev: Island.current
    readonly property bool shown: isle.ev !== null
    // What it showed last, so the content does not blink out while the capsule closes.
    property var last: null
    onEvChanged: if (isle.ev)
        isle.last = isle.ev
    readonly property var v: isle.view(isle.last)

    width: 2 * Theme.islandHalf
    height: Theme.barHeight

    readonly property var vpnWords: ({
            connecting: "Connecting…",
            connected: "Connected",
            disconnecting: "Disconnecting…",
            disconnected: "Off",
            error: "Did not connect"
        })
    // One event as the capsule's four fields: an icon and a name left of the logo, a level and a
    // word right of it.
    function view(e) {
        const none = {
            icon: "",
            left: "",
            right: "",
            level: -1,
            tone: Theme.colText,
            art: ""
        };
        if (!e)
            return none;
        const d = e.data;
        const pct = f => Math.round(f * 100) + "%";
        switch (e.kind) {
        case "volume":
            return Object.assign(none, {
                icon: d.muted || d.level <= 0 ? "volume_off" : (d.level <= 0.5 ? "volume_down" : "volume_up"),
                left: "Volume",
                right: d.muted ? "Muted" : pct(d.level),
                level: d.muted ? 0 : d.level
            });
        case "mic":
            return Object.assign(none, {
                icon: d.muted ? "mic_off" : "mic",
                left: "Microphone",
                right: d.muted ? "Muted" : "On"
            });
        case "brightness":
            return Object.assign(none, {
                icon: "brightness_medium",
                left: "Brightness",
                right: pct(d.level),
                level: Math.min(1, d.level)
            });
        case "dpi":
            return Object.assign(none, {
                icon: "mouse",
                left: "Mouse",
                right: d.value + " DPI"
            });
        case "vpn":
            return Object.assign(none, {
                icon: d.state === "connected" ? "shield_lock" : "shield",
                left: d.name,
                right: isle.vpnWords[d.state] || "",
                tone: d.state === "error" ? Theme.colCrit : Theme.colText
            });
        case "notification":
            return Object.assign(none, {
                icon: "notifications",
                left: d.app,
                right: d.summary
            });
        case "bluetooth":
            return Object.assign(none, {
                icon: d.on ? "bluetooth_connected" : "bluetooth_disabled",
                left: d.name,
                right: d.on ? "Connected" : "Disconnected"
            });
        case "media":
            return Object.assign(none, {
                icon: "music_note",
                left: d.artist,
                right: d.title,
                art: d.art || ""
            });
        case "critical":
            return Object.assign(none, {
                icon: "warning",
                left: d.title,
                right: d.text,
                tone: Theme.colCrit
            });
        }
        return none;
    }
    // A click leads to the surface that holds the rest of it.
    function act() {
        const k = isle.last ? isle.last.kind : "";
        if (k === "notification")
            Notifs.toggleCenter();
        else if (k === "media")
            isle.host.openMediaUnder(isle.barWindow);
        else if (k === "critical")
            Island.dismiss();
        else
            isle.host.openForTest("control");
    }

    // Half the logo's slot, then the wider side, then the padding: the same on both sides.
    readonly property int inner: Theme.barCenterWidth / 2
    readonly property int side: Math.min(Theme.islandHalf - isle.inner - Theme.sp3, Math.ceil(Math.max(leftRow.implicitWidth, rightRow.implicitWidth)))
    readonly property int half: isle.shown ? isle.inner + isle.side + Theme.sp3 : isle.inner

    Rectangle {
        id: capsule
        property real reach: isle.half
        Behavior on reach {
            NumberAnimation {
                duration: Theme.motionNormal
                easing.type: Easing.OutCubic
            }
        }
        x: Math.round(isle.width / 2 - capsule.reach)
        y: Theme.barCellY
        width: Math.round(2 * capsule.reach)
        height: Theme.barCell
        radius: height / 2
        color: Theme.colCellHoverFill
        opacity: isle.shown ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.motionFast
            }
        }
        clip: true

        RowLayout {
            id: leftRow
            x: Math.round(capsule.width / 2 - isle.inner - leftRow.width)
            width: Math.min(leftRow.implicitWidth, isle.side)
            height: parent.height
            spacing: Theme.sp1
            // The cover while media plays; the event's icon otherwise, and when a cover fails to load.
            ClippingRectangle {
                visible: isle.v.art !== "" && cover.status === Image.Ready
                implicitWidth: Theme.barLogo
                implicitHeight: Theme.barLogo
                radius: Theme.sp1
                color: Theme.colCellPressFill
                Image {
                    id: cover
                    anchors.fill: parent
                    source: isle.v.art
                    sourceSize.width: Theme.barLogo * 2
                    sourceSize.height: Theme.barLogo * 2
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Text {
                visible: !(isle.v.art !== "" && cover.status === Image.Ready)
                text: isle.v.icon
                color: isle.v.tone
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconBar
                font.variableAxes: Theme.iconAxes
            }
            Text {
                Layout.fillWidth: true
                text: isle.v.left
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                elide: Text.ElideRight
            }
        }
        RowLayout {
            id: rightRow
            x: Math.round(capsule.width / 2 + isle.inner)
            width: Math.min(rightRow.implicitWidth, isle.side)
            height: parent.height
            spacing: Theme.sp2
            Rectangle {
                visible: isle.v.level >= 0
                implicitWidth: Theme.sp6 * 2
                implicitHeight: Theme.sp1
                radius: height / 2
                color: Theme.colCellPressFill
                Rectangle {
                    width: Math.round(parent.width * Math.max(0, Math.min(1, isle.v.level)))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.colText
                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.motionFast
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: isle.v.right
                color: isle.v.tone
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                font.features: Theme.fontTabular
                elide: Text.ElideRight
            }
        }
        // The pointer on it holds it; a click leads on. Never the keyboard: it is not a window.
        MouseArea {
            anchors.fill: parent
            enabled: isle.shown
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: Island.freeze(containsMouse)
            onClicked: isle.act()
        }
    }
}

// The media panel (Spotifast), through the native Mpris service. `qs ipc call mpris toggle`, or
// `toggleAt <x>` from the bar's media pill, which hangs it under the pill.
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

Scope {
    id: root

    property bool panelVisible: false
    property int panelLeft: Theme.barTop // the screen x the bar asked for; the left edge otherwise
    property real positionNow: 0

    // It selects the Spotifast player (the fallback: whichever is playing; otherwise the 1st)
    readonly property var player: {
        const m = Mpris.players;
        const list = (m && m.values) ? m.values : [];
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && (p.identity === "Spotifast" || (p.dbusName || "").toLowerCase().indexOf("spotifast") >= 0))
                return p;
        }
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].isPlaying)
                return list[i];
        return list.length ? list[0] : null;
    }

    readonly property bool hasPlayer: !!root.player
    readonly property string title: (root.player && root.player.trackTitle) ? root.player.trackTitle : "—"
    readonly property string artist: {
        if (!root.player || !root.player.trackArtists)
            return "";
        const a = root.player.trackArtists;
        return Array.isArray(a) ? a.join(", ") : ("" + a);
    }
    readonly property string album: (root.player && root.player.trackAlbum) ? root.player.trackAlbum : ""
    readonly property string artUrl: (root.player && root.player.trackArtUrl) ? root.player.trackArtUrl : ""
    readonly property real length: (root.player && root.player.length) ? root.player.length : 0
    readonly property bool playing: !!(root.player && root.player.isPlaying)

    function refreshPosition() {
        root.positionNow = (root.player && root.player.positionSupported) ? root.player.position : 0;
    }

    function fmt(s) {
        if (!s || s < 0)
            return "0:00";
        const m = Math.floor(s / 60);
        const sec = Math.floor(s % 60);
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }

    IpcHandler {
        target: "mpris"

        function toggle(): void {
            root.panelVisible = !root.panelVisible;
            if (root.panelVisible)
                root.refreshPosition();
        }
        // The bar's media pill: hung under the pill at screen x `x`, like every bar panel.
        function toggleAt(x: int): void {
            root.panelLeft = x;
            root.panelVisible = !root.panelVisible;
            if (root.panelVisible)
                root.refreshPosition();
        }
        // "open" and not "show" (show collides with the `qs ipc show` subcommand)
        function open(): void {
            root.panelVisible = true;
            root.refreshPosition();
        }
        function hide(): void {
            root.panelVisible = false;
        }
    }

    // The progress bar's tick while playing and with the panel open
    Timer {
        interval: 1000
        repeat: true
        running: root.panelVisible && root.playing
        onTriggered: root.refreshPosition()
    }

    // Auto-closing when the mouse leaves the panel (the same as the VPN panel)
    Timer {
        interval: 2500
        running: root.panelVisible && !panelHover.hovered
        onTriggered: root.panelVisible = false
    }

    // It updates the position when the track changes or on play-pause
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            root.refreshPosition();
        }
        function onPositionChanged() {
            root.refreshPosition();
        }
        function onIsPlayingChanged() {
            root.refreshPosition();
        }
    }

    PanelWindow {
        id: panel
        WlrLayershell.namespace: "qs-panel"
        visible: root.panelVisible

        // On the main monitor, placed from the screen's edge sp1 under the bar (the same rule as BarPanel).
        screen: Theme.screenPrimary

        anchors {
            top: true
            left: true
        }
        exclusionMode: ExclusionMode.Ignore
        margins {
            top: Theme.bandTop
            left: root.panelLeft
        }

        implicitWidth: 360
        implicitHeight: content.implicitHeight + 28
        color: "transparent"

        GlassSurface {
            anchors.fill: parent
            level: "pop"

            transform: Translate {
                id: drop
            }
            PopIn {
                target: drop
                shown: panel.visible
            }

            HoverHandler {
                id: panelHover
            }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                // The header: the cover plus track/artist/album
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                        radius: 8
                        color: Theme.colTrack
                        clip: true

                        Image {
                            id: art
                            anchors.fill: parent
                            source: root.artUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: art.status !== Image.Ready
                            text: "󰓇"
                            color: Theme.colDim
                            font.pixelSize: 28
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.title
                            color: Theme.colText
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.artist !== ""
                            text: root.artist
                            color: Theme.colAccent
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.album !== ""
                            text: root.album
                            color: Theme.colDim
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                // The progress bar (clickable to seek)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: root.hasPlayer && root.length > 0

                    Rectangle {
                        id: track
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: Theme.colTrack

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.length > 0 ? root.positionNow / root.length : 0))
                            height: parent.height
                            radius: 3
                            color: Theme.colAccent
                            Behavior on width {
                                NumberAnimation {
                                    duration: Theme.motionSlow
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: root.player && root.player.canSeek
                            onClicked: mouse => {
                                if (root.player && root.length > 0) {
                                    root.player.position = (mouse.x / width) * root.length;
                                    root.refreshPosition();
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: root.fmt(root.positionNow)
                            color: Theme.colDim
                            font.pixelSize: 10
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.fmt(root.length)
                            color: Theme.colDim
                            font.pixelSize: 10
                        }
                    }
                }

                // The controls: previous / play-pause / next
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 18
                    visible: root.hasPlayer

                    CtlButton {
                        glyph: "󰒮"
                        enabled: root.player && root.player.canGoPrevious
                        onActivated: root.player.previous()
                    }
                    CtlButton {
                        glyph: root.playing ? "󰏤" : "󰐊"
                        big: true
                        enabled: root.player && root.player.canTogglePlaying
                        onActivated: root.player.togglePlaying()
                    }
                    CtlButton {
                        glyph: "󰒭"
                        enabled: root.player && root.player.canGoNext
                        onActivated: root.player.next()
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !root.hasPlayer
                    text: "No media player is active"
                    color: Theme.colDim
                    font.pixelSize: 12
                }
            }
        }
    }

    // A circular control button
    component CtlButton: Rectangle {
        id: btn

        property string glyph: ""
        property bool big: false
        signal activated

        implicitWidth: big ? 44 : 36
        implicitHeight: big ? 44 : 36
        radius: width / 2
        color: (area.containsMouse && btn.enabled) ? Theme.colHoverBgAccent : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: Theme.motionHover
                easing.type: Easing.OutQuad
            }
        }
        border.color: btn.enabled ? Theme.colAccent : Theme.colDim
        border.width: 1
        opacity: btn.enabled ? 1 : 0.4

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: Theme.colAccent
            font.pixelSize: btn.big ? 20 : 16
        }

        MouseArea {
            id: area
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            enabled: btn.enabled
            onClicked: btn.activated()
        }
    }
}

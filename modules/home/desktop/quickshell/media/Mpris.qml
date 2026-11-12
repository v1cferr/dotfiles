// The media panel, through the native Mpris service: the cover, the track, the wave of what is
// heard, the seek bar and the three keys. `qs ipc call mpris toggle`, or `toggleAt <x>` from the
// bar, which hangs it under the logo or the media item. docs/notes/desktop/island.md#the-media-panel
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

Scope {
    id: root

    property bool panelVisible: false
    property int panelLeft: Theme.barTop // the screen x the bar asked for; the left edge otherwise
    property real positionNow: 0
    // Opened by a hover on the island: it closes soon after the pointer leaves both.
    property bool byHover: false
    // Even, so the panel's middle is a whole pixel: the logo's.
    readonly property int panelWidth: 360
    readonly property int cover: Theme.sp6 * 3

    // The wave listens while the panel shows what plays.
    Binding {
        target: Audio
        property: "wavePanel"
        value: root.panelVisible && root.playing && !Theme.motionReduced
    }

    // The player and its track have one owner (Media.qml).
    readonly property var player: Media.player
    readonly property bool hasPlayer: Media.hasPlayer
    readonly property string title: Media.title
    readonly property string artist: Media.artist
    readonly property string album: Media.album
    readonly property string artUrl: Media.artUrl
    readonly property real length: Media.length
    readonly property bool playing: Media.playing

    // Only while the panel shows it: asking a player that is closing for its position logs a D-Bus
    // error per change, and with the panel closed nobody reads the answer.
    function refreshPosition() {
        if (!root.panelVisible)
            return;
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
            root.byHover = false;
            root.panelVisible = !root.panelVisible;
            if (root.panelVisible)
                root.refreshPosition();
        }
        // The bar's media pill: hung under the pill at screen x `x`, like every bar panel.
        function toggleAt(x: int): void {
            root.panelLeft = x;
            // A click on what a hover opened keeps it, as a pin does on the bar's panels.
            if (root.panelVisible && root.byHover) {
                root.byHover = false;
                return;
            }
            root.byHover = false;
            root.panelVisible = !root.panelVisible;
            if (root.panelVisible)
                root.refreshPosition();
        }
        // The island's hover: open it there, never close it.
        function openAt(x: int): void {
            root.panelLeft = x;
            if (!root.panelVisible) {
                root.byHover = true;
                root.panelVisible = true;
                root.refreshPosition();
            }
        }
        // "open" and not "show" (show collides with the `qs ipc show` subcommand)
        function open(): void {
            root.byHover = false;
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

    // It closes when the pointer is on neither the panel nor the island's media: soon after a
    // hover opened it, later after a click did.
    Timer {
        interval: root.byHover ? 600 : 2500
        running: root.panelVisible && !panelHover.hovered && !Media.hover
        onTriggered: root.panelVisible = false
    }
    Binding {
        target: Audio
        property: "panelOpen"
        value: root.panelVisible
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

        implicitWidth: root.panelWidth
        implicitHeight: content.implicitHeight + 2 * Theme.sp4
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
                anchors.margins: Theme.sp4
                spacing: Theme.sp3

                // The cover, and the track in three lines: what, by whom, from where.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp3

                    ClippingRectangle {
                        implicitWidth: root.cover
                        implicitHeight: root.cover
                        radius: Theme.radiusControl
                        color: Theme.colCellHoverFill
                        Text {
                            anchors.centerIn: parent
                            visible: art.status !== Image.Ready
                            text: "music_note"
                            color: Theme.colSubtext
                            font.family: Theme.iconFont
                            font.pixelSize: Theme.sp6
                            font.variableAxes: Theme.iconAxes
                        }
                        Image {
                            id: art
                            anchors.fill: parent
                            source: root.artUrl
                            sourceSize.width: root.cover * 2
                            sourceSize.height: root.cover * 2
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Theme.sp1 / 2

                        Text {
                            Layout.fillWidth: true
                            text: root.hasPlayer ? root.title : "Nothing is playing"
                            color: Theme.colText
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontTitle
                            font.weight: Theme.weightStrong
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: root.artist
                            color: Theme.colSubtext
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontBody
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: root.album !== "" ? root.album : Media.source
                            color: Theme.colDim
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontSmall
                            elide: Text.ElideRight
                        }
                    }

                    // Go to the window it plays in.
                    Key {
                        Layout.alignment: Qt.AlignTop
                        visible: root.hasPlayer
                        glyph: "open_in_new"
                        name: "Go to " + (Media.source || "the player")
                        onActivated: {
                            Media.reveal();
                            root.panelVisible = false;
                        }
                    }
                }

                // What is heard, across the panel: the island's wave with room to breathe.
                Wave {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.sp6
                    visible: Audio.wavePanel && Audio.bands.length > 0
                    mirror: true
                    bands: Audio.bands
                }

                // Where the track is: a press or a drag moves it there.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.sp1
                    visible: root.hasPlayer && root.length > 0

                    Item {
                        id: seek
                        Layout.fillWidth: true
                        implicitHeight: Theme.sp3
                        readonly property real part: Math.max(0, Math.min(1, root.length > 0 ? root.positionNow / root.length : 0))
                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: Theme.sp1
                            radius: height / 2
                            color: Theme.colCellHoverFill
                            Rectangle {
                                width: Math.round(Math.max(parent.height, seek.part * parent.width))
                                height: parent.height
                                radius: parent.radius
                                color: Qt.alpha(Theme.colText, 0.88)
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !!root.player && root.player.canSeek
                            function go(x) {
                                if (!root.player || root.length <= 0)
                                    return;
                                root.player.position = Math.max(0, Math.min(1, x / width)) * root.length;
                                root.refreshPosition();
                            }
                            onPressed: m => go(m.x)
                            onPositionChanged: m => {
                                if (pressed)
                                    go(m.x);
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: root.fmt(root.positionNow)
                            color: Theme.colDim
                            font.family: Theme.uiFont
                            font.features: Theme.fontTabular
                            font.pixelSize: Theme.fontMicro
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.fmt(root.length)
                            color: Theme.colDim
                            font.family: Theme.uiFont
                            font.features: Theme.fontTabular
                            font.pixelSize: Theme.fontMicro
                        }
                    }
                }

                // Previous, play or pause, next: centered on the panel, so under the logo.
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.sp4
                    visible: root.hasPlayer

                    Key {
                        glyph: "skip_previous"
                        name: "Previous track"
                        enabled: !!root.player && root.player.canGoPrevious
                        onActivated: root.player.previous()
                    }
                    Key {
                        glyph: root.playing ? "pause" : "play_arrow"
                        name: root.playing ? "Pause" : "Play"
                        main: true
                        enabled: !!root.player && root.player.canTogglePlaying
                        onActivated: root.player.togglePlaying()
                    }
                    Key {
                        glyph: "skip_next"
                        name: "Next track"
                        enabled: !!root.player && root.player.canGoNext
                        onActivated: root.player.next()
                    }
                }

                // The volume of what plays: the player's own when its stream is known, else the output's.
                Slider {
                    Layout.fillWidth: true
                    visible: root.hasPlayer
                    value: Audio.mediaVolume
                    dimmed: Audio.mediaMuted
                    icon: Audio.mediaMuted || Audio.mediaVolume <= 0 ? "volume_off" : (Audio.mediaVolume <= 0.5 ? "volume_down" : "volume_up")
                    name: Audio.mediaIsPlayer ? Media.source + " volume" : "Volume"
                    onMoved: v => Audio.setMediaVolume(v)
                    onIconClicked: Audio.toggleMediaMute()
                }
            }
        }
    }

    // A round transport key; the main one is filled, the two beside it are bare until hovered.
    component Key: Rectangle {
        id: key

        property string glyph: ""
        property string name: ""
        property bool main: false
        signal activated

        implicitWidth: key.main ? Theme.sp6 + Theme.sp4 : Theme.sp6 + Theme.sp2
        implicitHeight: implicitWidth
        radius: width / 2
        opacity: key.enabled ? 1 : Theme.opacityDisabled
        color: key.main ? Qt.alpha(Theme.colText, area.pressed ? 0.72 : (area.containsMouse ? 1 : 0.88)) : (area.pressed ? Theme.colPressFill : (area.containsMouse ? Theme.colHoverFill : "transparent"))
        Behavior on color {
            ColorAnimation {
                duration: Theme.motionHover
            }
        }
        Accessible.role: Accessible.Button
        Accessible.name: key.name

        Text {
            anchors.centerIn: parent
            text: key.glyph
            color: key.main ? Theme.colBgSolid : Theme.colText
            font.family: Theme.iconFont
            font.pixelSize: key.main ? Theme.sp6 : Theme.iconSymbol + 2
            font.variableAxes: Theme.iconAxes
        }
        MouseArea {
            id: area
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            enabled: key.enabled
            onClicked: key.activated()
        }
    }
}

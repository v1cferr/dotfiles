// What plays, to look at and to drive: the cover and the track, the wave of what is heard, the
// seek bar, the three keys, the volume and the way to its window. The media panel and the open
// island both show it. docs/notes/desktop/island.md#the-media-panel
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

ColumnLayout {
    id: card
    // On screen: the position is asked for, and ticks, only while it is.
    property bool active: false
    // The wave shows while its owner asked Audio for one.
    property bool wave: false
    // The key that leads to the player's window was used: the owner may close.
    signal revealed

    spacing: Theme.sp3
    readonly property int cover: Theme.sp6 * 3

    // The player and its track have one owner (Media.qml).
    readonly property var player: Media.player
    readonly property bool hasPlayer: Media.hasPlayer
    readonly property string title: Media.title
    readonly property string artist: Media.artist
    readonly property string album: Media.album
    readonly property string artUrl: Media.artUrl
    readonly property real length: Media.length
    readonly property bool playing: Media.playing

    // Only while it shows: asking a player that is closing for its position logs a D-Bus error
    // per change, and with nothing on screen nobody reads the answer.
    property real positionNow: 0
    // A player that stopped is not asked again: its position stands still, and one that stopped
    // because it is leaving the bus answers with an error (seen in the live log on 12/11/2026).
    function refreshPosition() {
        if (!card.active || !card.player || !card.player.positionSupported)
            return;
        if (card.player.isPlaying || card.positionNow === 0)
            card.positionNow = card.player.position;
    }
    onPlayerChanged: card.positionNow = 0
    onActiveChanged: card.refreshPosition()
    function fmt(s) {
        if (!s || s < 0)
            return "0:00";
        const m = Math.floor(s / 60);
        const sec = Math.floor(s % 60);
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }
    Timer {
        interval: 1000
        repeat: true
        running: card.active && card.playing
        onTriggered: card.refreshPosition()
    }
    Connections {
        target: card.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            card.refreshPosition();
        }
        function onPositionChanged() {
            card.refreshPosition();
        }
        function onIsPlayingChanged() {
            card.refreshPosition();
        }
    }

    // The cover, and the track in three lines: what, by whom, from where.
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp3

        ClippingRectangle {
            implicitWidth: card.cover
            implicitHeight: card.cover
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
                source: card.artUrl
                sourceSize.width: card.cover * 2
                sourceSize.height: card.cover * 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.sp1 / 2

            Text {
                Layout.fillWidth: true
                text: card.hasPlayer ? card.title : "Nothing is playing"
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontTitle
                font.weight: Theme.weightStrong
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.artist
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: card.album !== "" ? card.album : Media.source
                color: Theme.colDim
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
        }

        // Go to the window it plays in.
        Key {
            Layout.alignment: Qt.AlignTop
            visible: card.hasPlayer
            glyph: "open_in_new"
            name: "Go to " + (Media.source || "the player")
            onActivated: {
                Media.reveal();
                card.revealed();
            }
        }
    }

    // What is heard, across the panel: the island's wave with room to breathe.
    Wave {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.sp6
        visible: card.wave && Audio.bands.length > 0
        mirror: true
        bands: Audio.bands
    }

    // Where the track is: a press or a drag moves it there.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: Theme.sp1
        visible: card.hasPlayer && card.length > 0

        Item {
            id: seek
            Layout.fillWidth: true
            implicitHeight: Theme.sp3
            readonly property real part: Math.max(0, Math.min(1, card.length > 0 ? card.positionNow / card.length : 0))
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
                enabled: !!card.player && card.player.canSeek
                function go(x) {
                    if (!card.player || card.length <= 0)
                        return;
                    const to = Math.max(0, Math.min(1, x / width)) * card.length;
                    card.player.position = to;
                    card.positionNow = to;
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
                text: card.fmt(card.positionNow)
                color: Theme.colDim
                font.family: Theme.uiFont
                font.features: Theme.fontTabular
                font.pixelSize: Theme.fontMicro
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: card.fmt(card.length)
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
        visible: card.hasPlayer

        Key {
            glyph: "skip_previous"
            name: "Previous track"
            enabled: !!card.player && card.player.canGoPrevious
            onActivated: card.player.previous()
        }
        Key {
            glyph: card.playing ? "pause" : "play_arrow"
            name: card.playing ? "Pause" : "Play"
            main: true
            enabled: !!card.player && card.player.canTogglePlaying
            onActivated: card.player.togglePlaying()
        }
        Key {
            glyph: "skip_next"
            name: "Next track"
            enabled: !!card.player && card.player.canGoNext
            onActivated: card.player.next()
        }
    }

    // The volume of what plays: the player's own when its stream is known, else the output's.
    Slider {
        Layout.fillWidth: true
        visible: card.hasPlayer
        value: Audio.mediaVolume
        dimmed: Audio.mediaMuted
        icon: Audio.mediaMuted || Audio.mediaVolume <= 0 ? "volume_off" : (Audio.mediaVolume <= 0.5 ? "volume_down" : "volume_up")
        name: Audio.mediaIsPlayer ? Media.source + " volume" : "Volume"
        onMoved: v => Audio.setMediaVolume(v)
        onIconClicked: Audio.toggleMediaMute()
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

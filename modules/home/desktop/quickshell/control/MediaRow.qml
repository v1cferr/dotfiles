// Now playing, in one row: the cover, the track, and the three transport keys. It reads Media, the
// one owner of the player choice; the full panel with the seek bar stays the media panel.
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

Rectangle {
    id: row
    implicitHeight: Theme.sp6 * 2 + Theme.sp1
    radius: Theme.radiusSurface
    color: Qt.alpha(Theme.colText, 0.04)

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.sp2
        anchors.rightMargin: Theme.sp1
        spacing: Theme.sp2
        Rectangle {
            implicitWidth: Theme.barHeight
            implicitHeight: Theme.barHeight
            radius: Theme.radiusControl
            color: Theme.colCellHoverFill
            clip: true
            Text {
                anchors.centerIn: parent
                visible: art.status !== Image.Ready
                text: "music_note"
                color: Theme.colSubtext
                font.family: Theme.iconFont
                font.pixelSize: Theme.iconSymbol
                font.variableAxes: Theme.iconAxes
            }
            Image {
                id: art
                anchors.fill: parent
                source: Media.artUrl
                sourceSize.width: Theme.barHeight * 2
                sourceSize.height: Theme.barHeight * 2
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: Media.title
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                font.weight: Theme.weightStrong
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: Media.artist
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
        }
        IconButton {
            glyph: "skip_previous"
            name: "Previous track"
            enabled: !!Media.player && Media.player.canGoPrevious
            onClicked: Media.player.previous()
        }
        IconButton {
            glyph: Media.playing ? "pause" : "play_arrow"
            name: Media.playing ? "Pause" : "Play"
            enabled: !!Media.player && Media.player.canTogglePlaying
            onClicked: Media.player.togglePlaying()
        }
        IconButton {
            glyph: "skip_next"
            name: "Next track"
            enabled: !!Media.player && Media.player.canGoNext
            onClicked: Media.player.next()
        }
    }
}

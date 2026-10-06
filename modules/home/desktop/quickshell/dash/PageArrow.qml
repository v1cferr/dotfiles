// One of the two arrows beside the page dots: a glyph with a hover tint and a generous hit area.
import QtQuick
import "root:/"

Text {
    id: arrow
    property string glyph: "›"
    signal clicked

    text: arrow.glyph
    color: area.containsMouse ? Theme.colAccent : Theme.colSubtext
    font.family: Theme.uiFont
    font.pixelSize: 18
    font.bold: true

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -8
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: arrow.clicked()
    }
}

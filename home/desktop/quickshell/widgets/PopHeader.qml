// A panel's header: the title on the left, the verdict on the right, the hairline below. One shape
// for every popover, so the shell reads as a single surface.
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: head
    property string title: ""
    property string icon: ""
    property string verdict: ""
    property color verdictColor: Theme.colDim
    property bool rule: true

    Layout.fillWidth: true
    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Text {
            text: head.icon === "" ? head.title : head.icon + "  " + head.title
            color: Theme.colAccent
            font.family: Theme.uiFont
            font.pixelSize: 14
            font.bold: true
        }
        Item {
            Layout.fillWidth: true
        }
        Verdict {
            visible: head.verdict !== ""
            label: head.verdict
            accent: head.verdictColor
        }
    }
    Hairline {
        visible: head.rule
    }
}

// A Control Center page's header: the way back, then what the page is.
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

RowLayout {
    id: head
    property string title: ""
    signal back
    Layout.fillWidth: true
    spacing: Theme.sp1
    IconButton {
        glyph: "chevron_left"
        tint: Theme.colSubtext
        name: "Back"
        onClicked: head.back()
    }
    Text {
        Layout.fillWidth: true
        text: head.title
        color: Theme.colText
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontTitle
        font.weight: Theme.weightStrong
    }
}

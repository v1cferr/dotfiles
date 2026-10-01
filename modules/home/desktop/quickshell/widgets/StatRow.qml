// One line of "label, context, value". The label column has a fixed width so the values line up
// and do not dance as the numbers change width.
import QtQuick
import QtQuick.Layouts
import "root:/"

RowLayout {
    id: sr
    property string label: ""
    property string value: ""
    property string hint: ""
    property color valueColor: Theme.colText
    property int labelWidth: 62

    Layout.fillWidth: true
    spacing: 10

    Text {
        Layout.minimumWidth: sr.labelWidth
        text: sr.label
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 11
    }
    Text {
        Layout.fillWidth: true
        text: sr.hint
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: 10
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideLeft
    }
    Text {
        text: sr.value
        color: sr.valueColor
        font.family: Theme.uiFont
        font.pixelSize: 12
        font.bold: true
    }
}

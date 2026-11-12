// One row of a Control Center list (a network, a Bluetooth device): an icon, a name, what it is
// now, and an optional mark at the far end. A click or Enter acts on it.
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

Rectangle {
    id: row
    property string icon: "" // a Material Symbols name
    property string title: ""
    property string status: ""
    property color statusColor: Theme.colSubtext
    property string mark: "" // a Material Symbols name at the far end (a lock, a check)
    property bool lit: false // in use: the icon takes the accent
    signal clicked

    Layout.fillWidth: true
    implicitHeight: Theme.barHeight + Theme.sp1
    radius: Theme.radiusControl
    color: area.pressed ? Theme.colPressFill : (area.containsMouse ? Theme.colHoverFill : "transparent")
    Accessible.role: Accessible.Button
    Accessible.name: row.title + ", " + row.status

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.sp2
        anchors.rightMargin: Theme.sp2
        spacing: Theme.sp2
        Text {
            text: row.icon
            color: row.lit ? Theme.colAccent : Theme.colSubtext
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconSymbol
            font.variableAxes: Theme.iconAxes
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Text {
                Layout.fillWidth: true
                text: row.title
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                elide: Text.ElideRight
            }
            Text {
                visible: row.status !== ""
                Layout.fillWidth: true
                text: row.status
                color: row.statusColor
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
        }
        Text {
            visible: row.mark !== ""
            text: row.mark
            color: Theme.colDim
            font.family: Theme.iconFont
            font.pixelSize: Theme.iconBar
            font.variableAxes: Theme.iconAxes
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
    KeyTarget {
        onActivated: row.clicked()
    }
}

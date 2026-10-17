// A vertical hairline between two groups of controls inside one cluster: related things share a
// surface, and this is the only edge between them.
import QtQuick
import QtQuick.Layouts
import "root:/"

Rectangle {
    implicitWidth: Theme.hairline
    implicitHeight: Theme.sp4 - Theme.sp1
    Layout.alignment: Qt.AlignVCenter
    color: Theme.colEdge
}

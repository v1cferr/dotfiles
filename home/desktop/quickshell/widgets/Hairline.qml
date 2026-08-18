// The separator hairline, the same one in every panel. It was written by hand in 6 files, half of
// them with the border color as a literal (rule 11).
import QtQuick
import QtQuick.Layouts
import "root:/"

Rectangle {
    Layout.fillWidth: true
    implicitHeight: 1
    color: Theme.colBorder
    opacity: 0.5
}

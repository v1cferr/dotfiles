// A FLOATING CLUSTER: one glass surface holding a row of flat controls, so the bar reads as three
// groups over the wallpaper instead of a dozen bordered pills. docs/notes/desktop/bar.md
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

GlassSurface {
    id: cluster
    default property alias content: row.data

    level: "bar"
    implicitWidth: row.implicitWidth + 2 * Theme.sp1
    implicitHeight: Theme.barHeight
    // The width follows the content in one step: easing it would slide the anchored side clusters.
    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        x: Theme.sp1
        spacing: Theme.sp1
    }
}

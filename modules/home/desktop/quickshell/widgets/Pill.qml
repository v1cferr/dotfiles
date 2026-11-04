// The bar's control: one slanted glass cell (SlantCell) holding a glyph and a label. Its states, S1:
// neutral at rest and on hover, the accent only while its panel is open, a tinted cell for a state
// that needs a look. docs/notes/desktop/bar.md#cells. Its OWN file, since an inline component's
// handlers lose the root id on this Qt.
import QtQuick
import QtQuick.Layouts
import "root:/"

SlantCell {
    id: pill
    property string icon: ""
    // A vector icon in place of the glyph (the NixOS logo); `icon` stays the fallback if it fails.
    property url image: ""
    property string label: ""
    // Secondary text in the SAME pill, AFTER the label on purpose: the label is the main information
    // and owns the left edge, where the eye enters the pill.
    property string sub: ""
    property color accent: Theme.colText
    property color labelColor: pill.accent
    property bool bold: false
    // A second state in its OWN color, last in the row (the VPN pill's Tor), so it never borrows the accent.
    property string badge: ""
    property color badgeColor: Theme.colDim
    property int maxWidth: 0
    // Pinned: its panel is open by a click, so the control stays lit while the pointer is elsewhere.
    property bool selected: false
    // A state that needs a look (attention, a failure): the whole cell takes its color, readable from afar.
    property color tint: "transparent"
    // Off by choice (muted, a VPN down on purpose): a faded cell, never a failure.
    property bool off: false
    signal clicked
    signal rightClicked
    signal scrolledUp
    signal scrolledDown
    property alias hovered: area.containsMouse
    property bool italic: false
    // The content at the left edge instead of centered: a pill wider than its text (the focused
    // window's title, sized in steps so its neighbors do not jump) reads from where it starts.
    property bool leftAligned: false

    readonly property bool tinted: pill.tint.a > 0
    readonly property bool imageOk: pill.image != "" && img.status === Image.Ready
    implicitWidth: (pill.maxWidth > 0) ? Math.min(Theme.barCellWidth(prow.implicitWidth), pill.maxWidth) : Theme.barCellWidth(prow.implicitWidth)
    fill: area.pressed ? Theme.colCellPressFill : pill.selected ? Theme.colCellOpenFill : pill.tinted ? Qt.alpha(pill.tint, area.containsMouse ? 0.24 : 0.16) : area.containsMouse ? Theme.colCellHoverFill : pill.off ? Qt.alpha(Theme.colText, 0.04) : Theme.colCellFill
    edge: pill.selected ? Theme.colCellOpenEdge : pill.tinted ? Qt.alpha(pill.tint, 0.5) : area.containsMouse ? Theme.colCellHoverEdge : pill.off ? Qt.alpha(Theme.colText, 0.1) : Theme.colCellEdge
    marked: pill.selected

    // On the cell's center line (half a slant in from the top edge), whole pixels.
    RowLayout {
        id: prow
        anchors.verticalCenter: parent.verticalCenter
        // Never left of the padding: a clipped label (elided) starts at the pad, like a left-aligned one.
        x: Math.round(pill.leftAligned ? Theme.barPad + pill.dx / 2 : Math.max(Theme.barPad, (pill.width - prow.implicitWidth) / 2) + pill.dx / 2)
        width: Math.min(prow.implicitWidth, pill.width - 2 * Theme.barPad)
        spacing: Theme.sp1
        opacity: pill.off ? 0.55 : 1
        Image {
            id: img
            visible: pill.imageOk
            source: pill.image
            sourceSize.width: 16
            sourceSize.height: 16
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        Text {
            visible: pill.icon !== "" && !pill.imageOk
            text: pill.icon
            color: pill.accent
            font.family: Theme.uiFont
            font.pixelSize: Theme.iconBar
        }
        Text {
            visible: pill.label !== ""
            Layout.fillWidth: pill.maxWidth > 0
            text: pill.label
            color: pill.labelColor
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontBody
            font.bold: pill.bold
            font.italic: pill.italic
            elide: Text.ElideRight
        }
        Text {
            visible: pill.sub !== ""
            text: pill.sub
            color: Theme.colSubtext
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontSmall
        }
        Text {
            visible: pill.badge !== ""
            text: pill.badge
            color: pill.badgeColor
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontBody
        }
    }
    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: m => {
            if (m.button === Qt.RightButton)
                pill.rightClicked();
            else
                pill.clicked();
        }
        onWheel: w => {
            if (w.angleDelta.y > 0)
                pill.scrolledUp();
            else
                pill.scrolledDown();
        }
    }
}

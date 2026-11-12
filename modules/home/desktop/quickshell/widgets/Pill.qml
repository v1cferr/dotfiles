// The bar's control: a glyph and a label, bare on the strip. A rounded highlight shows only on hover,
// while its panel is open (the accent) or for a state that needs a look (a tint).
// docs/notes/desktop/bar.md#items. Its OWN file, since an inline component's handlers lose the root id.
import QtQuick
import QtQuick.Layouts
import "root:/"

Item {
    id: pill
    property string icon: ""
    // A vector icon in place of the glyph; `icon` stays the fallback if it fails.
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
    // A state that needs a look (attention, a failure): the highlight takes its color, readable from afar.
    property color tint: "transparent"
    // Off by choice (muted, a VPN down on purpose): faded content, never a failure.
    property bool off: false
    signal clicked
    signal rightClicked
    signal scrolledUp
    signal scrolledDown
    property alias hovered: area.containsMouse

    // An icon written as a Material Symbols name ("volume_up") draws in the icon font; anything else
    // is a glyph of the text font's fallback (a Nerd Font brand icon).
    readonly property bool symbol: /^[a-z0-9_]+$/.test(pill.icon)
    readonly property bool tinted: pill.tint.a > 0
    readonly property bool imageOk: pill.image != "" && img.status === Image.Ready
    implicitWidth: (pill.maxWidth > 0) ? Math.min(Theme.barCellWidth(prow.implicitWidth), pill.maxWidth) : Theme.barCellWidth(prow.implicitWidth)
    implicitHeight: Theme.barCell

    // The highlight. At rest it is the hover fill at zero alpha, so the fade never passes through black.
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusControl
        color: area.pressed ? Theme.colCellPressFill : pill.selected ? Theme.colCellOpenFill : pill.tinted ? Qt.alpha(pill.tint, area.containsMouse ? 0.24 : 0.16) : area.containsMouse ? Theme.colCellHoverFill : Qt.alpha(Theme.colCellHoverFill, 0)
        Behavior on color {
            ColorAnimation {
                duration: Theme.motionHover
            }
        }
    }

    RowLayout {
        id: prow
        anchors.verticalCenter: parent.verticalCenter
        // Never left of the padding: a clipped label (elided) starts at the pad.
        x: Math.round(Math.max(Theme.barPad, (pill.width - prow.implicitWidth) / 2))
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
            font.family: pill.symbol ? Theme.iconFont : Theme.uiFont
            font.pixelSize: pill.symbol ? Theme.iconSymbol : Theme.iconBar
            font.variableAxes: pill.symbol ? Theme.iconAxes : ({})
        }
        Text {
            visible: pill.label !== ""
            Layout.fillWidth: pill.maxWidth > 0
            text: pill.label
            color: pill.labelColor
            font.family: Theme.uiFont
            font.pixelSize: Theme.fontBody
            font.weight: (pill.bold) ? Theme.weightStrong : Theme.weightText
            font.features: Theme.fontTabular
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

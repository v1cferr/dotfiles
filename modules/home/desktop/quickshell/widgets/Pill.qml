// The bar's control: a FLAT segment inside a glass cluster, so it has no edge of its own and a hover
// is a neutral fill. Its OWN file, since an inline component's handlers lose the root id on this Qt.
import QtQuick
import QtQuick.Layouts
import "root:/"

Rectangle {
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
    // A resting tint (an operational chip's state on glass); hover and press still read over it.
    property color fill: "transparent"
    signal clicked
    signal rightClicked
    signal scrolledUp
    signal scrolledDown
    property alias hovered: area.containsMouse
    property bool italic: false
    // The content at the left edge instead of centered: a pill wider than its text (the focused
    // window's title, sized in steps so its neighbors do not jump) reads from where it starts.
    property bool leftAligned: false

    readonly property int padX: Theme.sp2
    readonly property bool imageOk: pill.image != "" && img.status === Image.Ready
    implicitWidth: (pill.maxWidth > 0) ? Math.min(prow.implicitWidth + 2 * pill.padX, pill.maxWidth) : prow.implicitWidth + 2 * pill.padX
    implicitHeight: Theme.barControl
    radius: Theme.radiusControl
    color: area.pressed ? Theme.colPressFill : (area.containsMouse ? Theme.colHoverFill : (pill.selected ? Theme.colSelectFill : pill.fill))
    Behavior on color {
        ColorAnimation {
            duration: Theme.motionHover
            easing.type: Easing.OutQuad
        }
    }

    // Centered, so a pill given a fixed slot (the clock's symmetric neighbors) keeps its content in the middle.
    RowLayout {
        id: prow
        anchors.verticalCenter: parent.verticalCenter
        x: pill.leftAligned ? pill.padX : Math.max(pill.padX, Math.round((pill.width - prow.implicitWidth) / 2))
        width: Math.min(prow.implicitWidth, pill.width - 2 * pill.padX)
        spacing: Theme.sp1
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

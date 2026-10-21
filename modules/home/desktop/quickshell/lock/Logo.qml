// My logo beside the signature, drawn in the type's own ink (no frame, no color of its own): the
// SVG's alpha as a mask over the ink. The logo is STATE (LOCK_LOGO, my.lockscreen.logo); no file,
// no logo.
import Quickshell
import QtQuick
import QtQuick.Effects

Item {
    id: mark

    property string source: Quickshell.env("LOCK_LOGO") || ""
    property color ink: "white"

    width: 56
    height: 56
    visible: logo.status === Image.Ready

    Image {
        id: logo
        anchors.fill: parent
        source: mark.source ? "file://" + mark.source : ""
        sourceSize: Qt.size(112, 112) // twice the drawn size: crisp on the scaled-down edge
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }
    // Colorization would not do: it keeps the drawing's luminance, and black stays black.
    Rectangle {
        id: fill
        anchors.fill: parent
        color: mark.ink
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        source: fill
        maskEnabled: true
        maskSource: logo
    }
}

// The artist's seal beside the signature, as a print carries one: my logo knocked out of a
// vermilion square. The logo is STATE (LOCK_LOGO, my.lockscreen.logo); no file, no seal.
import Quickshell
import QtQuick
import QtQuick.Effects

Rectangle {
    id: seal

    property string source: Quickshell.env("LOCK_LOGO") || ""
    property color paper: "#f4efe4"

    width: 64
    height: 64
    radius: 6
    color: "#c4342c"
    visible: logo.status === Image.Ready

    Image {
        id: logo
        anchors.centerIn: parent
        width: 44
        height: 44
        source: seal.source ? "file://" + seal.source : ""
        sourceSize: Qt.size(88, 88) // twice the drawn size: crisp on the scaled-down edge
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }
    // The paper's tone in the logo's shape (its alpha as a mask), so it reads as cut out of the seal.
    // Colorization would not do: it keeps the drawing's luminance, and black stays black.
    Rectangle {
        id: paperFill
        anchors.fill: logo
        color: seal.paper
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: logo
        source: paperFill
        maskEnabled: true
        maskSource: logo
    }
}

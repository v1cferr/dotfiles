// A pane of REAL glass over a backdrop the window draws itself (the lock's print): the region
// under the pane, blurred and lifted, a tint that keeps text AA, a light rim and a soft shadow.
// It samples an Item, not the compositor, so it only works over content in the same window.
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "root:/"

Item {
    id: glass

    required property Item backdrop
    property real radius: 28
    property real blur: 1.0 // MultiEffect's 0..1, against blurMax below
    property int blurMax: 64
    property real saturation: 0.35 // vibrancy: the print's color carried through the frost
    property real brightness: -0.08
    property color tint: Theme.colBgSolid
    property real tintAlpha: 0.38 // raise it until the content reads; the caller measures
    default property alias content: inner.data
    property real contentOpacity: 1 // what a caller fades (a card while its data loads), never the glass
    property bool contentHalo: false // a dark halo on the content, for a glass too thin to hold AA by its tint
    // Where the pane sits on the backdrop. A binding cannot see an ancestor move (a Column laying
    // its children out), so it is re-read after layout and on every change of size.
    property rect region: Qt.rect(0, 0, 0, 0)
    function place() {
        if (!glass.backdrop)
            return;
        const p = glass.mapToItem(glass.backdrop, 0, 0);
        glass.region = Qt.rect(p.x, p.y, glass.width, glass.height);
    }
    onWidthChanged: Qt.callLater(glass.place)
    onHeightChanged: Qt.callLater(glass.place)
    onXChanged: Qt.callLater(glass.place)
    onYChanged: Qt.callLater(glass.place)
    Component.onCompleted: Qt.callLater(glass.place)
    Timer {
        interval: 250 // after the first layout pass of every ancestor
        running: true
        onTriggered: glass.place()
    }

    RectangularShadow {
        anchors.fill: parent
        offset.y: 14
        blur: 36
        radius: glass.radius
        color: Qt.rgba(0, 0, 0, 0.35)
    }

    ClippingRectangle {
        anchors.fill: parent
        radius: glass.radius
        color: "transparent"

        ShaderEffectSource {
            id: under
            anchors.fill: parent
            sourceItem: glass.backdrop
            // The backdrop's pixels exactly under the pane, in its own coordinates (glass.region).
            sourceRect: glass.region
            live: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: under
            blurEnabled: true
            blur: glass.blur
            blurMax: glass.blurMax
            saturation: glass.saturation
            brightness: glass.brightness
        }
        Rectangle {
            anchors.fill: parent
            color: glass.tint
            opacity: glass.tintAlpha
        }
        // Light falls from above: a sheen that fades by a third of the way down.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: Qt.rgba(1, 1, 1, 0.10)
                }
                GradientStop {
                    position: 0.35
                    color: Qt.rgba(1, 1, 1, 0)
                }
            }
        }
    }

    // The rim: a hairline, brighter where the light hits (top) than at the foot.
    Rectangle {
        anchors.fill: parent
        radius: glass.radius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.16)
    }

    Item {
        id: inner
        anchors.fill: parent
        opacity: glass.contentOpacity
        layer.enabled: glass.contentHalo
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.55
            shadowBlur: 0.5
            shadowHorizontalOffset: 0
            shadowVerticalOffset: 1
            blurMax: 24
        }
    }
}

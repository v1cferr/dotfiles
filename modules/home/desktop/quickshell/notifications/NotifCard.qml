// A notification card (toasts plus the center), CONTEXTUAL GLASS: no frame, hierarchy by type and
// spacing, a 3 px strip only for a critical one. The freedesktop urgency is the only semantics a
// notification reliably carries, so normal and low read neutral: docs/notes/desktop/nixos-center.md
// Its OWN file because in an inline component the root's id does not resolve in nested handlers.
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "root:/"
import "root:/widgets"

Rectangle {
    id: card
    property var notif
    property bool isPopup: false
    readonly property bool critical: card.notif !== null && card.notif !== undefined && card.notif.urgency === NotificationUrgency.Critical
    // A toast is the compact variant: a smaller icon and the body held to two lines.
    readonly property bool compact: card.isPopup

    // The "default" action (the one that "activates"/focuses the app that notified) becomes a
    // little arrow at the top of the card; the other actions stay as text buttons.
    readonly property var defaultAction: {
        if (!card.notif)
            return null;
        const acts = card.notif.actions || [];
        for (let i = 0; i < acts.length; i++)
            if (acts[i].identifier === "default")
                return acts[i];
        return null;
    }
    readonly property var extraActions: {
        if (!card.notif)
            return [];
        return (card.notif.actions || []).filter(function (a) {
            return a.identifier !== "default";
        });
    }

    // The notifying app's icon from the current theme, else the bell. hasThemeIcon avoids the checkered
    // placeholder the provider returns for a missing icon. Everything here is the sender's, so untrusted.
    readonly property string wantedName: {
        if (!card.notif)
            return "";
        const img = card.notif.image || "";
        const m = img.match(/^image:\/\/icon\/([^\/].*)$/);
        if (m)
            return m[1];
        const ai = card.notif.appIcon || "";
        if (ai !== "" && !ai.startsWith("/") && ai.indexOf("://") < 0)
            return ai;
        return "";
    }
    readonly property string themeIcon: {
        if (!card.notif)
            return "";
        const img = card.notif.image || "";
        // The spec allows a bare path in image-path (ZapFast's avatars); Quickshell hands it over as
        // an icon NAME, image://icon//home/..., so it never resolves in the theme.
        const bare = img.match(/^(?:image:\/\/icon\/)?(\/.+)$/);
        if (bare)
            return "file://" + bare[1];
        if (img.startsWith("image://icon/"))
            return Quickshell.hasThemeIcon(card.wantedName) ? img : "";
        if (img !== "")
            return img;               // dado de imagem real (capa/print/file://)
        const ai = card.notif.appIcon || "";
        if (ai.startsWith("/"))
            return "file://" + ai;
        if (card.wantedName !== "")
            return Quickshell.hasThemeIcon(card.wantedName) ? Quickshell.iconPath(card.wantedName) : "";
        return "";
    }
    // A real picture (not a theme icon) gets rounded: a circle for a chat message, as a contact
    // photo (category im.*), and soft corners for the rest (a cover, a screenshot).
    readonly property bool isPicture: card.themeIcon !== "" && card.notif && (card.notif.image || "") !== "" && !(/^image:\/\/icon\/[^\/]/.test(card.notif.image))
    readonly property bool isChat: card.notif && card.notif.hints && ("" + (card.notif.hints.category || "")).startsWith("im.")
    readonly property string iconSource: card.themeIcon

    // A toast JOINING others settles into its slot; the first is a new layer, and Hyprland fades it.
    // The toasts' ScriptModel keeps every other card alive, so only the newcomer is created.
    Component.onCompleted: if (card.isPopup && Notifs.popups.length > 1)
        arrive.start()
    // A toast joining others settles 8 px down into its slot while it fades in; no bounce.
    transform: Translate {
        id: slot
    }
    ParallelAnimation {
        id: arrive
        NumberAnimation {
            target: slot
            property: "y"
            from: -8
            to: 0
            duration: Theme.motionNormal
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.motionNormal
            easing.type: Easing.OutCubic
        }
    }
    implicitHeight: cardRow.implicitHeight + 2 * (card.compact ? Theme.sp2 : Theme.sp3)
    radius: Theme.radiusSurface
    // A toast is glass of its own; inside the Center a card is a faint inset on the panel's glass.
    color: card.isPopup ? Theme.colSurfacePop : (cardHover.hovered ? Theme.colHoverFill : Qt.alpha(Theme.colText, 0.04))
    Behavior on color {
        ColorAnimation {
            duration: Theme.motionHover
        }
    }
    HoverHandler {
        id: cardHover
    }
    // Critical only: the one urgency that means something, said by a strip AND the bold red summary.
    Rectangle {
        visible: card.critical
        x: 0
        y: Theme.sp2
        width: 3
        height: card.height - 2 * Theme.sp2
        radius: 1.5
        color: Theme.colCrit
    }

    // The toast's auto-dismiss; Critical stays until an interaction.
    Timer {
        running: card.isPopup && card.notif && card.notif.urgency !== NotificationUrgency.Critical
        interval: (card.notif && card.notif.urgency === NotificationUrgency.Low) ? 4000 : 6000
        onTriggered: Notifs.removePopup(card.notif)
    }
    // Closed from outside (the app, the center, an expiry) removes the toast too.
    Connections {
        target: card.notif
        function onClosed(reason) {
            Notifs.removePopup(card.notif);
        }
    }

    // The RIGHT button anywhere on the card dismisses it. It sits at the bottom (z-order): the
    // action buttons handle the left one on top, and the right one propagates.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: Notifs.dismiss(card.notif)
    }

    // In the Center only: Enter opens what notified (the default action), Delete dismisses it.
    KeyTarget {
        activeFocusOnTab: !card.isPopup
        onActivated: if (card.defaultAction) {
            card.defaultAction.invoke();
            Notifs.dismiss(card.notif);
        }
        onDeleted: Notifs.dismiss(card.notif)
    }

    RowLayout {
        id: cardRow
        anchors.fill: parent
        anchors.margins: card.compact ? Theme.sp2 : Theme.sp3
        anchors.leftMargin: (card.compact ? Theme.sp2 : Theme.sp3) + (card.critical ? Theme.sp1 : 0)
        spacing: Theme.sp3

        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: card.compact ? 28 : 32
            implicitHeight: card.compact ? 28 : 32
            ClippingRectangle {
                id: nclip
                anchors.fill: parent
                // it disappears (falling back to the bell) if the source is empty OR fails to
                // load, which avoids Qt's magenta/black "broken image" checkerboard.
                visible: card.iconSource !== "" && nimg.status !== Image.Error
                color: "transparent"
                radius: card.isPicture ? (card.isChat ? width / 2 : 8) : 0
                Image {
                    id: nimg
                    anchors.fill: parent
                    source: card.iconSource
                    asynchronous: true
                    // a picture fills the shape (crop); an icon keeps its whole outline (fit)
                    fillMode: card.isPicture ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                    sourceSize.width: 64
                    sourceSize.height: 64
                }
            }
            Text {
                anchors.centerIn: parent
                visible: !nclip.visible
                text: "󰂚"
                color: card.critical ? Theme.colCrit : Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: card.compact ? 18 : 20
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: card.notif ? card.notif.appName : ""
                    color: Theme.colSubtext
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }
                // When it arrived; re-read each time the list repaints, which is enough for minutes.
                Text {
                    text: card.notif ? Notifs.agoText(card.notif) : ""
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontMicro
                    Layout.rightMargin: Theme.sp1
                }
                // The little arrow: it invokes the "default" action, focusing/opening the app that notified.
                Text {
                    visible: card.defaultAction !== null
                    text: "󰏌"
                    color: arrowArea.containsMouse ? Theme.colAccent : Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 13
                    Layout.rightMargin: 6
                    MouseArea {
                        id: arrowArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: {
                            if (card.defaultAction)
                                card.defaultAction.invoke();
                            Notifs.dismiss(card.notif);
                        }
                    }
                }
                Text {
                    text: "✕"
                    color: closeArea.containsMouse ? Theme.colRed : Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        onClicked: Notifs.dismiss(card.notif)
                    }
                }
            }
            Text {
                visible: text !== ""
                Layout.fillWidth: true
                text: card.notif ? card.notif.summary : ""
                color: card.critical ? Theme.colCrit : Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                font.bold: true
                wrapMode: Text.WordWrap
                maximumLineCount: card.compact ? 1 : 3
                elide: Text.ElideRight
            }
            Text {
                visible: text !== ""
                Layout.fillWidth: true
                text: card.notif ? card.notif.body : ""
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                maximumLineCount: card.compact ? 2 : 6
                elide: Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                visible: card.extraActions.length > 0
                spacing: 6
                Repeater {
                    model: card.extraActions
                    Rectangle {
                        required property var modelData
                        implicitWidth: actLabel.implicitWidth + 2 * Theme.sp3
                        implicitHeight: 24
                        radius: Theme.radiusControl
                        color: actArea.containsMouse ? Theme.colHoverFill : Qt.alpha(Theme.colText, 0.06)
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.motionHover
                                easing.type: Easing.OutQuad
                            }
                        }
                        Text {
                            id: actLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            color: Theme.colText
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontSmall
                        }
                        MouseArea {
                            id: actArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                modelData.invoke();
                                Notifs.dismiss(card.notif);
                            }
                        }
                    }
                }
            }
        }
    }
}

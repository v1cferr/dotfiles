// A notification card (toasts plus the center). Its OWN file because in an inline component the
// root's id does not resolve in nested handlers, which broke dismiss and the actions.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "root:/"

Rectangle {
    id: card
    property var notif
    property bool isPopup: false

    function urgColor(u) {
        if (u === NotificationUrgency.Critical)
            return Theme.colRed;
        if (u === NotificationUrgency.Low)
            return Theme.colDim;
        return Theme.colAccent;
    }

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

    // The notifying app's icon: the current theme first, then breeze ONLY in this card, then the bell.
    // hasThemeIcon avoids the checkered placeholder the provider returns for a missing icon.
    readonly property string wantedName: {
        if (!card.notif)
            return "";
        const img = card.notif.image || "";
        const m = img.match(/^image:\/\/icon\/(.+)$/);
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
    property string fallbackIcon: ""
    readonly property string iconSource: card.themeIcon !== "" ? card.themeIcon : card.fallbackIcon

    // The breeze fallback when the current theme does not have the icon (async; a direct argv,
    // with no shell, and a sanitized name, since appName is untrusted content).
    function resolveFallback() {
        card.fallbackIcon = "";
        const n = card.wantedName;
        if (card.themeIcon !== "" || n === "" || !(/^[a-zA-Z0-9._-]+$/.test(n)))
            return;
        iconFinder.command = ["find", "/usr/share/icons/breeze-dark/apps", "/usr/share/icons/breeze/apps", "(", "-name", n + ".svg", "-o", "-name", n + ".png", ")", "-print", "-quit"];
        iconFinder.running = true;
    }
    Component.onCompleted: card.resolveFallback()
    Process {
        id: iconFinder
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim();
                if (p)
                    card.fallbackIcon = "file://" + p;
            }
        }
    }

    implicitHeight: cardRow.implicitHeight + 20
    radius: 12
    color: Theme.colCard
    border.color: card.notif ? card.urgColor(card.notif.urgency) : Theme.colBorder
    border.width: 1

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

    RowLayout {
        id: cardRow
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36
            Image {
                id: nimg
                anchors.fill: parent
                // it disappears (falling back to the bell) if the source is empty OR fails to
                // load, which avoids Qt's magenta/black "broken image" checkerboard.
                visible: card.iconSource !== "" && nimg.status !== Image.Error
                source: card.iconSource
                asynchronous: true
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 36
                sourceSize.height: 36
            }
            Text {
                anchors.centerIn: parent
                visible: !nimg.visible
                text: "󰂚"
                color: card.notif ? card.urgColor(card.notif.urgency) : Theme.colAccent
                font.family: Theme.uiFont
                font.pixelSize: 22
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
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    elide: Text.ElideRight
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
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 13
                font.bold: true
                wrapMode: Text.WordWrap
            }
            Text {
                visible: text !== ""
                Layout.fillWidth: true
                text: card.notif ? card.notif.body : ""
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: 11
                textFormat: Text.StyledText
                wrapMode: Text.WordWrap
                opacity: 0.85
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
                        implicitWidth: actLabel.implicitWidth + 18
                        implicitHeight: 24
                        radius: 7
                        color: actArea.containsMouse ? Theme.colHoverBg : "transparent"
                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.hoverAnim
                                easing.type: Easing.OutQuad
                            }
                        }
                        border.color: Theme.colBorder
                        border.width: 1
                        Text {
                            id: actLabel
                            anchors.centerIn: parent
                            text: modelData.text
                            color: Theme.colText
                            font.family: Theme.uiFont
                            font.pixelSize: 10
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

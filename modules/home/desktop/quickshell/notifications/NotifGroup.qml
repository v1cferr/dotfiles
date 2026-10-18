// A GROUP of similar notifications in the NixOS Center's history, folded to one card: the app, how
// many, what they said (the distinct bodies with their counts), and when the newest came. A view
// over the history, never a replacement: every notification stays in the server, and expanding
// shows each one with its own actions. The grouping rule: docs/notes/desktop/nixos-center.md
import Quickshell
import QtQuick
import QtQuick.Layouts
import "root:/"

Rectangle {
    id: grp
    property var items: [] // newest first
    property bool open: false
    signal toggled
    signal dismissAll

    readonly property var newest: grp.items.length > 0 ? grp.items[0] : null
    // The bodies said, most frequent first: "4 × Capture saved · 2 × Capture aborted".
    readonly property string tally: {
        const counts = ({});
        const order = [];
        for (const n of grp.items) {
            const b = ("" + (n.body || "")).replace(/<[^>]*>/g, "").split("\n")[0].trim() || "(no text)";
            const k = b.length > 40 ? b.slice(0, 39) + "…" : b;
            if (counts[k] === undefined) {
                counts[k] = 0;
                order.push(k);
            }
            counts[k]++;
        }
        order.sort((a, b) => counts[b] - counts[a]);
        const shown = order.slice(0, 2).map(k => counts[k] + " × " + k);
        return shown.join(" · ") + (order.length > 2 ? " · +" + (order.length - 2) + " more" : "");
    }
    readonly property string appIcon: {
        const ai = grp.newest ? ("" + (grp.newest.appIcon || "")) : "";
        if (ai.startsWith("/"))
            return "file://" + ai;
        return ai !== "" && ai.indexOf("://") < 0 && Quickshell.hasThemeIcon(ai) ? Quickshell.iconPath(ai) : "";
    }

    implicitHeight: row.implicitHeight + 2 * Theme.sp3
    radius: Theme.radiusSurface
    color: hover.hovered ? Theme.colHoverFill : Qt.alpha(Theme.colText, 0.04)
    Behavior on color {
        ColorAnimation {
            duration: Theme.motionHover
        }
    }
    HoverHandler {
        id: hover
    }
    Accessible.role: Accessible.Button
    Accessible.name: (grp.newest ? grp.newest.appName : "") + ", " + grp.items.length + " notifications, " + (grp.open ? "expanded" : "collapsed")

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.margins: Theme.sp3
        spacing: Theme.sp3

        // The app's icon, else the bell; with the count stacked on it, so "many" reads at a glance.
        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 32
            implicitHeight: 32
            Image {
                id: gimg
                anchors.fill: parent
                visible: grp.appIcon !== "" && status !== Image.Error
                source: grp.appIcon
                sourceSize.width: 64
                sourceSize.height: 64
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                visible: !gimg.visible
                text: "󰂚"
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: 20
            }
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -4
                width: Math.max(16, countText.implicitWidth + 6)
                height: 16
                radius: 8
                color: Theme.colSelectFill
                border.color: Theme.colBgSolid
                border.width: 1
                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: grp.items.length
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontMicro
                    font.bold: true
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: (grp.newest ? grp.newest.appName : "") + " · " + grp.items.length + " events"
                    color: Theme.colSubtext
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontSmall
                    elide: Text.ElideRight
                }
                Text {
                    text: grp.newest ? Notifs.agoText(grp.newest) : ""
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontMicro
                    Layout.rightMargin: Theme.sp1
                }
                Text {
                    text: grp.open ? "󰅃" : "󰅀"
                    color: hover.hovered ? Theme.colAccent : Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontLabel
                }
                Text {
                    text: "✕"
                    color: closeArea.containsMouse ? Theme.colCrit : Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontBody
                    Layout.leftMargin: Theme.sp1
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: grp.dismissAll()
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: grp.newest ? grp.newest.summary : ""
                color: Theme.colText
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontBody
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: grp.tally
                color: Theme.colSubtext
                font.family: Theme.uiFont
                font.pixelSize: Theme.fontSmall
                elide: Text.ElideRight
            }
        }
    }
    // A click anywhere else on the card expands or folds it.
    TapHandler {
        onTapped: grp.toggled()
    }
}

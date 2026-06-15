// Pílula de mídia (Spotify) na Waybar + painel de controle no hover.
// A pílula fica na ponta ESQUERDA da barra (largura fixa; a Waybar reserva a
// margem esquerda). Passar o mouse na pílula OU no painel mantém o painel
// aberto; sai dos dois -> fecha após uma folga. Estilo Tokyo Night, igual à
// estética de pílula da Waybar. Usa Quickshell.Services.Mpris.
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    // Paleta Tokyo Night
    readonly property color colBg: "#f21a1b26"
    readonly property color colBorder: "#414868"
    readonly property color colText: "#c0caf5"
    readonly property color colDim: "#565f89"
    readonly property color colAccent: "#7aa2f7"
    readonly property color colGreen: "#a6e3a1"
    readonly property color colYellow: "#f9e2af"
    readonly property color colTrack: "#283041"
    // Pílula (mesma cara da Waybar): bg #1a1b26 ~86%, borda #414868 ~35%
    readonly property color pillBg: "#db1a1b26"
    readonly property color pillBorder: "#59414868"
    readonly property string uiFont: "JetBrainsMono Nerd Font"

    property real positionNow: 0

    // hover-open
    property bool pillHovered: false
    property bool panelHovered: false
    property bool panelVisible: false
    onPillHoveredChanged: root.updateOpen()
    onPanelHoveredChanged: root.updateOpen()
    function updateOpen() {
        if (root.pillHovered || root.panelHovered) {
            closeTimer.stop();
            if (!root.panelVisible)
                root.refreshPosition();
            root.panelVisible = true;
        } else {
            closeTimer.restart();
        }
    }
    Timer {
        id: closeTimer
        interval: 300
        onTriggered: if (!root.pillHovered && !root.panelHovered)
            root.panelVisible = false
    }

    // Seleciona o player do Spotify (fallback: tocando; senão o 1º)
    readonly property var player: {
        const m = Mpris.players;
        const list = (m && m.values) ? m.values : [];
        for (let i = 0; i < list.length; i++) {
            const p = list[i];
            if (p && (p.identity === "Spotify" || (p.dbusName || "").toLowerCase().indexOf("spotify") >= 0))
                return p;
        }
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].isPlaying)
                return list[i];
        return list.length ? list[0] : null;
    }

    readonly property bool hasPlayer: !!root.player
    readonly property string title: (root.player && root.player.trackTitle) ? root.player.trackTitle : "—"
    readonly property string artist: {
        if (!root.player || !root.player.trackArtists)
            return "";
        const a = root.player.trackArtists;
        return Array.isArray(a) ? a.join(", ") : ("" + a);
    }
    readonly property string album: (root.player && root.player.trackAlbum) ? root.player.trackAlbum : ""
    readonly property string artUrl: (root.player && root.player.trackArtUrl) ? root.player.trackArtUrl : ""
    readonly property real length: (root.player && root.player.length) ? root.player.length : 0
    readonly property bool playing: !!(root.player && root.player.isPlaying)

    // texto/ícone da pílula
    readonly property string pillText: {
        if (!root.hasPlayer)
            return "Spotify";
        return root.artist ? (root.artist + " - " + root.title) : root.title;
    }
    readonly property color pillColor: root.playing ? root.colGreen : (root.hasPlayer ? root.colYellow : root.colDim)

    function refreshPosition() {
        root.positionNow = (root.player && root.player.positionSupported) ? root.player.position : 0;
    }
    function fmt(s) {
        if (!s || s < 0)
            return "0:00";
        const m = Math.floor(s / 60);
        const sec = Math.floor(s % 60);
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }

    // Mantido pra flexibilidade (ex.: keybind): qs ipc call mpris toggle
    IpcHandler {
        target: "mpris"
        function toggle(): void {
            root.panelVisible = !root.panelVisible;
            if (root.panelVisible)
                root.refreshPosition();
        }
        function open(): void {
            root.panelVisible = true;
            root.refreshPosition();
        }
        function hide(): void {
            root.panelVisible = false;
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.panelVisible && root.playing
        onTriggered: root.refreshPosition()
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            root.refreshPosition();
        }
        function onPositionChanged() {
            root.refreshPosition();
        }
        function onIsPlayingChanged() {
            root.refreshPosition();
        }
    }

    function dp1OrNull() {
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === "DP-1")
                return screens[i];
        return null;
    }

    // ===== PÍLULA (ponta esquerda da barra) =====
    PanelWindow {
        id: pill
        screen: root.dp1OrNull()
        anchors {
            top: true
            left: true
        }
        margins {
            top: 4
            left: 4
        }
        exclusiveZone: 0
        implicitWidth: 220
        implicitHeight: 26
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 8
            color: root.pillBg
            border.color: root.pillBorder
            border.width: 1

            HoverHandler {
                id: pillHover
                onHoveredChanged: root.pillHovered = hovered
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 6

                Text {
                    text: "󰝚"
                    color: root.pillColor
                    font.family: root.uiFont
                    font.pixelSize: 13
                }
                Text {
                    Layout.fillWidth: true
                    text: root.pillText
                    color: root.hasPlayer ? root.colText : root.colDim
                    font.family: root.uiFont
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ===== PAINEL (logo abaixo da pílula) =====
    PanelWindow {
        id: panel
        visible: root.panelVisible
        screen: root.dp1OrNull()
        anchors {
            top: true
            left: true
        }
        margins {
            top: 33
            left: 4
        }
        exclusiveZone: 0
        implicitWidth: 360
        implicitHeight: content.implicitHeight + 28
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: root.colBg
            border.color: root.colBorder
            border.width: 1

            HoverHandler {
                id: panelHover
                onHoveredChanged: root.panelHovered = hovered
            }

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 14
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 64
                        Layout.preferredHeight: 64
                        radius: 8
                        color: root.colTrack
                        clip: true

                        Image {
                            id: art
                            anchors.fill: parent
                            source: root.artUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: art.status !== Image.Ready
                            text: "󰓇"
                            color: root.colDim
                            font.family: root.uiFont
                            font.pixelSize: 28
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.title
                            color: root.colText
                            font.family: root.uiFont
                            font.pixelSize: 14
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.artist !== ""
                            text: root.artist
                            color: root.colAccent
                            font.family: root.uiFont
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.album !== ""
                            text: root.album
                            color: root.colDim
                            font.family: root.uiFont
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    visible: root.hasPlayer && root.length > 0

                    Rectangle {
                        Layout.fillWidth: true
                        height: 6
                        radius: 3
                        color: root.colTrack

                        Rectangle {
                            width: parent.width * Math.max(0, Math.min(1, root.length > 0 ? root.positionNow / root.length : 0))
                            height: parent.height
                            radius: 3
                            color: root.colAccent
                            Behavior on width {
                                NumberAnimation {
                                    duration: 250
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.player && root.player.canSeek
                            onClicked: mouse => {
                                if (root.player && root.length > 0) {
                                    root.player.position = (mouse.x / width) * root.length;
                                    root.refreshPosition();
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: root.fmt(root.positionNow)
                            color: root.colDim
                            font.family: root.uiFont
                            font.pixelSize: 10
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        Text {
                            text: root.fmt(root.length)
                            color: root.colDim
                            font.family: root.uiFont
                            font.pixelSize: 10
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 18
                    visible: root.hasPlayer

                    CtlButton {
                        glyph: "󰒮"
                        enabled: root.player && root.player.canGoPrevious
                        onActivated: root.player.previous()
                    }
                    CtlButton {
                        glyph: root.playing ? "󰏤" : "󰐊"
                        big: true
                        enabled: root.player && root.player.canTogglePlaying
                        onActivated: root.player.togglePlaying()
                    }
                    CtlButton {
                        glyph: "󰒭"
                        enabled: root.player && root.player.canGoNext
                        onActivated: root.player.next()
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: !root.hasPlayer
                    text: "Nenhum player de mídia ativo"
                    color: root.colDim
                    font.family: root.uiFont
                    font.pixelSize: 12
                }
            }
        }
    }

    component CtlButton: Rectangle {
        id: btn

        property string glyph: ""
        property bool big: false
        signal activated

        implicitWidth: big ? 44 : 36
        implicitHeight: big ? 44 : 36
        radius: width / 2
        color: (area.containsMouse && btn.enabled) ? "#337aa2f7" : "transparent"
        border.color: btn.enabled ? root.colAccent : root.colDim
        border.width: 1
        opacity: btn.enabled ? 1 : 0.4

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            color: root.colAccent
            font.family: root.uiFont
            font.pixelSize: btn.big ? 20 : 16
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            enabled: btn.enabled
            onClicked: btn.activated()
        }
    }
}

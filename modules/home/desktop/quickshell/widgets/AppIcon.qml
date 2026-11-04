// An app's own icon from its .desktop entry, by class or process name; a neutral glyph when there is
// none (Hyprland, quickshell). The entries load asynchronously, so the lookup re-runs when they arrive.
import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import "root:/"
import "root:/data"

Item {
    id: app
    property string name: ""
    property int size: 16
    property int glyphSize: app.size
    property int glyphWeight: 300
    // Greyed toward the dim text, for an app that is not the subject (an inactive workspace's windows).
    property bool tinted: false

    // The window's process, when known: a Steam game is found by the app id in its environment.
    property int pid: 0

    // The .desktop entry first; then a Steam game's own icon; a Wine app has neither, so then the
    // icon Bottles extracted for it.
    readonly property string source: {
        if (DesktopEntries.applications.values.length > 0) {
            const e = DesktopEntries.heuristicLookup(app.name);
            // A web app's entry, written by Chrome, names its icon by absolute path, not by theme name.
            if (e && e.icon && e.icon.startsWith("/"))
                return "file://" + e.icon;
            if (e && e.icon && Quickshell.hasThemeIcon(e.icon))
                return Quickshell.iconPath(e.icon);
        }
        return SteamIcons.path(app.name, app.pid) || WineIcons.path(app.name);
    }
    implicitWidth: app.size
    implicitHeight: app.size

    IconImage {
        id: img
        anchors.fill: parent
        visible: app.source !== "" && !app.tinted
        implicitSize: app.size
        source: app.source
    }
    MultiEffect {
        anchors.fill: parent
        visible: app.source !== "" && app.tinted
        source: img
        saturation: -1
        colorization: 0.45
        colorizationColor: Theme.colDim
    }
    Text {
        visible: app.source === ""
        anchors.centerIn: parent
        text: "deployed_code"
        color: Theme.colSubtext
        font.family: "Material Symbols Rounded"
        font.pixelSize: app.glyphSize
        font.variableAxes: {
            "wght": app.glyphWeight
        }
    }
}

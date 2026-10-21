// One monitor's face of the lock, chosen by connector: the primary gets the clock and the field,
// the secondary the data. Keys typed on ANY face go to the one shared buffer.
import Quickshell
import QtQuick
import "root:/"

Item {
    id: face

    required property var auth
    required property string screenName
    readonly property bool primary: face.screenName === Theme.primaryMonitor || face.screenName === (Quickshell.env("LOCK_PRIMARY") || "")
    readonly property string session: Quickshell.env("LOCK_SESSION") || ""

    focus: true
    Component.onCompleted: face.forceActiveFocus()
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            face.auth.submit();
        else if (event.key === Qt.Key_Backspace)
            (event.modifiers & Qt.ControlModifier) ? face.auth.clear() : face.auth.erase();
        else if (event.key === Qt.Key_Escape)
            face.auth.clear();
        else if (event.text.length > 0 && event.text.charCodeAt(0) >= 32)
            face.auth.type(event.text);
        event.accepted = true;
    }

    Image {
        anchors.fill: parent
        source: face.session ? "file://" + face.session + (face.primary ? "/primary" : "/secondary") : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: false
        cache: false
    }

    Text {
        visible: face.primary
        anchors.centerIn: parent
        text: "•".repeat(face.auth.buffer.length) || (face.auth.busy ? "…" : "senha")
        color: face.auth.fails > 0 ? Theme.colRed : Theme.colText
        font.pixelSize: 40
    }
}

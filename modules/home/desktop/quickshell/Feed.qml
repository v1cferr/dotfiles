// One glance-feed source as a QML object (modules/home/desktop/glance-feed): `data` is its document,
// read from the SQLite cache at start and again ONLY when the feed rewrites the source's stamp,
// which it does only when the content changed. No network here: docs/notes/desktop/glance-feed.md
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: feed

    required property string name
    property var data: null       // the document, null until the cache has one
    property real updatedAt: 0    // when the content last CHANGED (s)
    property real checkedAt: 0    // when the feed last asked the network about it (s)
    property string error: ""     // why the last refresh failed, "" when it did not
    property string source: ""    // what produced it ("open-meteo:ecmwf_ifs", "inmet", ...)
    signal changed

    readonly property string dir: Quickshell.env("HOME") + "/.cache/glance"

    function read() {
        reader.running = true;
    }

    Process {
        id: reader
        command: ["glance-feed", "read", feed.name]
        stdout: StdioCollector {
            onStreamFinished: {
                let j;
                try {
                    j = JSON.parse(text);
                } catch (e) {
                    return;
                }
                if (!j || j.json === undefined)
                    return;
                feed.updatedAt = j.updated_at || 0;
                feed.checkedAt = j.checked_at || 0;
                feed.error = j.error || "";
                feed.source = j.source || "";
                feed.data = j.json;
                feed.changed();
            }
        }
    }
    // The stamp is rewritten only on a real change; watching it is the whole notification channel.
    FileView {
        path: feed.dir + "/stamps/" + feed.name
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            feed.read();
        }
    }
    // Until the first document arrives (the cache still empty, or `glance-feed` not on the PATH
    // yet right after a rebuild), ask again every 30 s instead of waiting for a stamp that may not
    // move for hours.
    Timer {
        interval: 30000
        repeat: true
        running: feed.data === null
        onTriggered: feed.read()
    }
    Component.onCompleted: feed.read()
}

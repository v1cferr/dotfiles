// One monitor's print: picked from its pools (not one of the last few shown), scaled to COVER the
// screen around the sidecar's focus, never past the image's edge. No print means the palette.
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"

Item {
    id: wall

    property var pools: [] // directories, searched one level deep
    property string historyFile: "" // this role's recently shown, so two monitors never race
    property int avoid: 5 // how many recent prints to skip while the pool is larger than that
    property string path: ""
    property var meta: ({}) // the sidecar `<name>.json`: artist, title, focus…
    readonly property bool ready: img.status === Image.Ready
    readonly property bool failed: img.status === Image.Error || (wall.listed && wall.path === "")
    property bool listed: false
    readonly property var focal: {
        const f = wall.meta.focus;
        return Array.isArray(f) && f.length === 2 ? [Math.min(1, Math.max(0, f[0])), Math.min(1, Math.max(0, f[1]))] : [0.5, 0.5];
    }
    signal shown

    clip: true

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.colBgSolid
            }
            GradientStop {
                position: 1
                color: Theme.colTrack
            }
        }
    }

    Image {
        id: img
        source: wall.path ? "file://" + wall.path : ""
        // Decoded straight to cover the screen: a 100 Mpx print never lands in memory at full size.
        sourceSize: Qt.size(wall.width, wall.height)
        fillMode: Image.PreserveAspectCrop
        width: Math.max(wall.width, implicitWidth)
        height: Math.max(wall.height, implicitHeight)
        x: Math.min(0, Math.max(wall.width - width, wall.width / 2 - wall.focal[0] * width))
        y: Math.min(0, Math.max(wall.height - height, wall.height / 2 - wall.focal[1] * height))
        asynchronous: true
        cache: false
        smooth: true
        mipmap: true
        onStatusChanged: if (status === Image.Ready)
            wall.shown()
    }

    FileView {
        id: history
        path: wall.historyFile
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: sidecar
        path: wall.path ? wall.path.replace(/\.[^./]+$/, ".json") : ""
        printErrors: false
        onLoaded: {
            try {
                wall.meta = JSON.parse(sidecar.text()) || {};
            } catch (e) {
                wall.meta = {};
            }
        }
    }

    Process {
        running: wall.pools.length > 0
        command: ["find", "-L"].concat(wall.pools).concat(["-maxdepth", "1", "-type", "f", "(", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.png", "-o", "-iname", "*.webp", ")"])
        stdout: StdioCollector {
            onStreamFinished: {
                const files = text.split("\n").filter(f => f);
                let seen = [];
                try {
                    seen = JSON.parse(history.text() || "[]");
                } catch (e) {}
                const keep = Math.min(wall.avoid, Math.max(0, files.length - 1));
                const recent = seen.slice(-keep);
                const fresh = files.filter(f => recent.indexOf(f) < 0);
                const pool = fresh.length ? fresh : files;
                wall.path = pool.length ? pool[Math.floor(Math.random() * pool.length)] : "";
                wall.listed = true;
                if (wall.path && wall.historyFile)
                    history.setText(JSON.stringify(seen.concat([wall.path]).slice(-20)));
            }
        }
    }
}

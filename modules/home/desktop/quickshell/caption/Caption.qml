// The wallpaper's CAPTION: what the photo on each screen shows, bottom-right, UNDER every window.
// Why it is drawn by the shell and not burnt into the image: docs/notes/desktop/desktop-plumbing.md
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "root:/"

Scope {
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: cap
            required property var modelData
            screen: modelData

            // The wide pool feeds the main panel and the tall one the other, the split the shuffle
            // script already uses, so each screen reads the caption of its OWN photo.
            readonly property string pool: cap.modelData && cap.modelData.name === Theme.primaryMonitor ? "wide" : "tall"

            anchors {
                bottom: true
                right: true
            }
            margins {
                bottom: 20
                right: 24
            }
            aboveWindows: false // the bottom layer: over hyprpaper, under every window
            exclusionMode: ExclusionMode.Ignore // it reserves nothing, windows tile as if it were not there
            mask: Region {} // an empty input region: every click goes through to the desktop
            color: "transparent"
            implicitWidth: col.implicitWidth
            implicitHeight: col.implicitHeight
            visible: meta.name !== "" || meta.title !== ""

            FileView {
                path: Quickshell.env("HOME") + "/.cache/wallpaper/" + cap.pool + ".json"
                watchChanges: true
                onFileChanged: reload()
                JsonAdapter {
                    id: meta
                    property string name: ""
                    property string title: ""
                    property string distance: ""
                    property string constellation: ""
                    property string credit: ""
                }
            }

            // A raised 1 px shadow and no box: legible over the black of space without a panel
            // competing with the galaxy for the eye.
            component Line: Text {
                Layout.alignment: Qt.AlignRight
                visible: text !== ""
                font.family: Theme.uiFont
                style: Text.Raised
                styleColor: "#cc000000"
            }

            ColumnLayout {
                id: col
                spacing: 3

                Line {
                    text: meta.name
                    color: Theme.colText
                    font.pixelSize: 26
                    font.bold: true
                    font.letterSpacing: 1
                }
                Line {
                    text: meta.title
                    color: Theme.colSubtext
                    font.pixelSize: 14
                    font.italic: true
                }
                Line {
                    text: [meta.distance, meta.constellation].filter(x => x !== "").join("  ·  ")
                    color: Theme.colSubtext
                    font.pixelSize: 13
                }
                Line {
                    Layout.topMargin: 4
                    text: meta.credit
                    color: Theme.colDim
                    font.pixelSize: 11
                }
            }
        }
    }
}

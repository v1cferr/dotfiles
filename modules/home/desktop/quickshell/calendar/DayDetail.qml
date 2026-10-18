// A DAY's detail: every event on it after the filters, each with what it is in law, where and for
// whom it holds, its basis, how sure it is, and its official sources (a click opens one). What
// the year view only hints at a glance is spelled out here. docs/notes/desktop/calendar.md
import QtQuick
import QtQuick.Layouts
import "root:/"

ColumnLayout {
    id: det
    required property string iso // "YYYY-MM-DD"
    required property var events // the day's occurrences, filtered
    property int hidden: 0       // events the filters hide that day
    property var host: null      // the Bar's Scope: scope colors and launch
    spacing: Theme.sp3

    readonly property var dowNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property string heading: {
        if (det.iso.length !== 10)
            return "";
        const d = new Date(+det.iso.slice(0, 4), +det.iso.slice(5, 7) - 1, +det.iso.slice(8, 10));
        return det.dowNames[d.getDay()] + ", " + det.iso.slice(8, 10) + "/" + det.iso.slice(5, 7) + "/" + det.iso.slice(0, 4);
    }
    function fmtDay(s) {
        return s ? s.slice(8, 10) + "/" + s.slice(5, 7) + "/" + s.slice(0, 4) : "";
    }

    Text {
        text: det.heading
        color: Theme.colText
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontTitle
        font.bold: true
    }
    Text {
        visible: det.events.length === 0
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        text: det.hidden > 0 ? "Nothing with the current filters (" + det.hidden + " hidden)." : "No holiday or observance on this day."
        color: Theme.colDim
        font.family: Theme.uiFont
        font.pixelSize: Theme.fontSmall
    }

    Repeater {
        model: det.events
        delegate: RowLayout {
            id: ev
            required property var modelData
            readonly property var o: ev.modelData
            readonly property color tone: det.host ? det.host.scopeColor(Holidays.scopeOf(ev.o)) : Theme.colText
            Layout.fillWidth: true
            spacing: Theme.sp2
            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredHeight: evCol.implicitHeight
                implicitWidth: 3
                radius: 1.5
                color: ev.tone
            }
            ColumnLayout {
                id: evCol
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: ev.o.display
                    color: Theme.colText
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontBody
                    font.bold: true
                }
                Text {
                    visible: ev.o.name !== ev.o.display
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: ev.o.name
                    color: Theme.colSubtext
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontSmall
                }
                // Label: value rows, the label dim and fixed so the values line up.
                Repeater {
                    model: [
                        ["Type", Holidays.kindWord(ev.o) + (ev.o.partial ? ", " + Holidays.partialWord(ev.o.partial) : "")],
                        ["Scope", Holidays.scopeNames[Holidays.scopeOf(ev.o)] + (Holidays.scopeOf(ev.o) === "sc" ? " — SP" : "")],
                        ["For", Holidays.forWhom(ev.o)],
                        ["Basis", ev.o.basis],
                        ["Status", Holidays.statusWord(ev.o.status) + (ev.o.status === "verified" && ev.o.verified_at ? " · checked " + det.fmtDay(ev.o.verified_at) : "")]
                    ].filter(r => r[1])
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.sp2
                        Text {
                            Layout.preferredWidth: 48
                            Layout.alignment: Qt.AlignTop
                            text: modelData[0]
                            color: Theme.colDim
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontSmall
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: modelData[1]
                            color: modelData[0] === "Status" ? (ev.o.status === "verified" ? Theme.colOk : Theme.colWarn) : Theme.colSubtext
                            font.family: Theme.uiFont
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                }
                Text {
                    visible: !!ev.o.notes
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: ev.o.notes || ""
                    color: Theme.colDim
                    font.family: Theme.uiFont
                    font.pixelSize: Theme.fontSmall
                    font.italic: true
                }
                // The sources: the official publications, each opening in the browser.
                Repeater {
                    model: ev.o.sources
                    delegate: Rectangle {
                        id: srcRow
                        required property string modelData
                        readonly property var s: Holidays.source(srcRow.modelData)
                        visible: srcRow.s !== null
                        Layout.fillWidth: true
                        implicitHeight: srcCol.implicitHeight + Theme.sp1 * 2
                        radius: Theme.radiusControl
                        color: srcArea.containsMouse ? Theme.colHoverFill : "transparent"
                        ColumnLayout {
                            id: srcCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.sp1
                            anchors.rightMargin: Theme.sp1
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: "󰌹  " + (srcRow.s ? srcRow.s.title : "")
                                color: Theme.colAccent
                                font.family: Theme.uiFont
                                font.pixelSize: Theme.fontSmall
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: srcRow.s ? srcRow.s.authority + (srcRow.s.check === "unreachable" ? " · could not be re-read on " + det.fmtDay(srcRow.s.checked_at) : " · read " + det.fmtDay(srcRow.s.checked_at)) : ""
                                color: srcRow.s && srcRow.s.check === "unreachable" ? Theme.colWarn : Theme.colDim
                                font.family: Theme.uiFont
                                font.pixelSize: Theme.fontMicro
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            id: srcArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (srcRow.s && det.host)
                                det.host.launch(["xdg-open", srcRow.s.url])
                        }
                        Accessible.role: Accessible.Link
                        Accessible.name: srcRow.s ? "Open " + srcRow.s.title : ""
                    }
                }
            }
        }
    }
}

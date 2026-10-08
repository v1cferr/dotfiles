pragma Singleton
// INMET, the official second source next to the ECMWF numbers: the forecasters' text per day (per
// period today and tomorrow) and the ACTIVE ALERTS for this municipality. Both come from
// glance-feed's cache, already matched by IBGE code and stripped of polygons and icons, so this
// file never touches the network. Why: docs/notes/desktop/dash.md, docs/notes/desktop/glance-feed.md
import Quickshell
import QtQuick
import "root:/"

Singleton {
    id: root

    property var days: ({})  // "YYYY-MM-DD" -> {summary, max, min, periods: {manha, tarde, noite}}
    property var alerts: []  // this municipality's, soonest first: {event, severity, from, to, until, risk}
    property real now: Date.now()

    // Alerts in force right now, the ones a glance must not miss.
    readonly property var activeNow: root.alerts.filter(a => a.from <= root.now && root.now <= a.to)

    function isoOf(br) { // "07/10/2026" -> "2026-10-07"
        const p = (br || "").split("/");
        return p.length === 3 ? p[2] + "-" + p[1] + "-" + p[0] : "";
    }
    function readForecast() {
        const doc = forecastFeed.data || {};
        const out = ({});
        for (const br in doc) {
            const d = doc[br];
            const per = d.periods || null;
            const parts = per ? ["manha", "tarde", "noite"].filter(k => per[k]).map(k => per[k]) : [d];
            const main = per ? (per.tarde || per.manha || per.noite) : d;
            out[root.isoOf(br)] = {
                summary: main.resumo || "",
                max: Math.max(...parts.map(p => Number(p.temp_max))),
                min: Math.min(...parts.map(p => Number(p.temp_min))),
                periods: per ? {
                    manha: per.manha ? per.manha.resumo : "",
                    tarde: per.tarde ? per.tarde.resumo : "",
                    noite: per.noite ? per.noite.resumo : ""
                } : null
            };
        }
        root.days = out;
    }
    function readAlerts() {
        // Local wall times ("2026-10-08T00:00"), as INMET states them.
        root.alerts = (alertsFeed.data || []).map(a => ({
                    event: a.event || "",
                    severity: a.severity || "",
                    from: new Date(a.start + ":00").getTime(),
                    to: new Date(a.end + ":59").getTime(),
                    until: a.until || "",
                    risk: String(a.risk || "")
                }));
    }

    // The severity's color: INMET's own ladder (potential danger, danger, great danger).
    function color(sev) {
        const s = (sev || "").toLowerCase();
        return s.indexOf("grande") >= 0 ? Theme.colRed : (s.indexOf("potencial") >= 0 ? Theme.colYellow : Theme.colPeach);
    }

    Feed {
        id: forecastFeed
        name: "inmet_forecast"
        onChanged: root.readForecast()
    }
    Feed {
        id: alertsFeed
        name: "inmet_alerts"
        onChanged: root.readAlerts()
    }
    // "In force now" is a matter of the clock as much as of the data.
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }
}

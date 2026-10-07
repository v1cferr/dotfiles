pragma Singleton
// INMET, the official second source next to the ECMWF numbers: the forecasters' text per day (per
// period today and tomorrow) and the ACTIVE ALERTS for this municipality, matched by IBGE code.
// Polled every 30 min; a failed poll keeps the last good answer. Why: docs/notes/desktop/dash.md
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"

Singleton {
    id: root

    // INMET's API answers only clients that look like a browser (a bare curl gets dropped).
    readonly property string ua: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130 Safari/537.36"
    property string ibge: "3548906" // my.weather.ibge, read from weather.json below
    property var days: ({})  // "YYYY-MM-DD" -> {summary, max, min, periods: {manha, tarde, noite}}
    property var alerts: []  // this municipality's, soonest first
    property real fetched: 0

    // Alerts in force right now, the ones a glance must not miss.
    readonly property var activeNow: root.alerts.filter(a => a.from <= Date.now() && Date.now() <= a.to)

    function isoOf(br) { // "07/10/2026" -> "2026-10-07"
        const p = (br || "").split("/");
        return p.length === 3 ? p[2] + "-" + p[1] + "-" + p[0] : "";
    }
    function parseForecast(text) {
        let j;
        try {
            j = JSON.parse(text);
        } catch (e) {
            return;
        }
        const city = j[root.ibge];
        if (!city)
            return;
        const out = ({});
        for (const br in city) {
            const d = city[br];
            const per = d.manha || d.tarde || d.noite ? d : null;
            const main = per ? (d.tarde || d.manha || d.noite) : d;
            out[root.isoOf(br)] = {
                summary: main.resumo || "",
                max: Number((per ? Math.max(...["manha", "tarde", "noite"].filter(k => d[k]).map(k => d[k].temp_max)) : d.temp_max)),
                min: Number((per ? Math.min(...["manha", "tarde", "noite"].filter(k => d[k]).map(k => d[k].temp_min)) : d.temp_min)),
                periods: per ? {
                    manha: d.manha ? d.manha.resumo : "",
                    tarde: d.tarde ? d.tarde.resumo : "",
                    noite: d.noite ? d.noite.resumo : ""
                } : null
            };
        }
        root.days = out;
        root.fetched = Date.now();
    }
    function parseAlerts(text) {
        let j;
        try {
            j = JSON.parse(text);
        } catch (e) {
            return;
        }
        const all = (j.hoje || []).concat(j.futuro || []);
        const mine = all.filter(a => String(a.geocodes || "").split(",").indexOf(root.ibge) >= 0);
        // INMET's dates are midnight UTC plus a local hh:mm; local wall time is date + hh:mm.
        const at = (d, hm) => new Date((d || "").slice(0, 10) + "T" + (hm || "00:00") + ":00").getTime();
        let risk = "";
        root.alerts = mine.map(a => {
            // `riscos` arrives as a JSON string of a list, or as the list itself.
            try {
                const r = Array.isArray(a.riscos) ? a.riscos : JSON.parse(a.riscos || "[]");
                risk = String(Array.isArray(r) ? (r[0] || "") : r);
            } catch (e) {
                risk = String(a.riscos || "");
            }
            return {
                id: a.id_aviso,
                event: a.descricao || "",
                severity: a.severidade || "",
                from: at(a.data_inicio, a.hora_inicio),
                to: at(a.data_fim, a.hora_fim),
                until: a.hora_fim || "",
                risk: risk
            };
        }).sort((x, y) => x.from - y.from);
    }

    // The severity's color: INMET's own ladder (potential danger, danger, great danger).
    function color(sev) {
        const s = (sev || "").toLowerCase();
        return s.indexOf("grande") >= 0 ? Theme.colRed : (s.indexOf("potencial") >= 0 ? Theme.colYellow : Theme.colPeach);
    }

    FileView {
        path: "/home/v1cferr/.config/theme/weather.json"
        watchChanges: true
        onLoaded: {
            try {
                const c = JSON.parse(text());
                if (c.ibge)
                    root.ibge = c.ibge;
            } catch (e) {}
        }
        onFileChanged: reload()
    }
    Process {
        id: fc
        command: ["curl", "-sS", "-m", "20", "-A", root.ua, "https://apiprevmet3.inmet.gov.br/previsao/" + root.ibge]
        stdout: StdioCollector {
            onStreamFinished: root.parseForecast(text)
        }
    }
    Process {
        id: av
        command: ["curl", "-sS", "-m", "20", "-A", root.ua, "https://apiprevmet3.inmet.gov.br/avisos/ativos"]
        stdout: StdioCollector {
            onStreamFinished: root.parseAlerts(text)
        }
    }
    Timer {
        interval: 1800000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            fc.running = true;
            av.running = true;
        }
    }
}

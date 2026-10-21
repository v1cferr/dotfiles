pragma Singleton
// The weather NOW and today from glance-feed's cache (no network here), with the pt-BR condition
// from my.weather (weather.json): what the lock's LG shows. docs/notes/desktop/glance-feed.md
import Quickshell
import Quickshell.Io
import QtQuick
import "root:/"

Singleton {
    id: root

    // Never an old forecast shown as current: a run older than 12 h (two missed ECMWF IFS runs) is
    // no forecast at all. docs/notes/desktop/weather.md#the-failure-paths
    readonly property bool ok: !isNaN(root.temp) && feed.updatedAt > 0 && Date.now() / 1000 - feed.updatedAt < 12 * 3600
    readonly property bool loading: feed.data === null // the cache not read yet, not "no forecast"
    property real temp: NaN
    property real feels: NaN
    property int code: -1
    property real high: NaN
    property real low: NaN
    property real rain: NaN // today's max chance, %
    property string issued: "" // the forecast run's hour, "HH:MM"
    readonly property string condition: {
        const t = root.conf.conditions;
        return t && t[root.code] !== undefined ? t[root.code] : "";
    }
    // A Material Symbols name for the WMO code: the lock draws icons from that one font.
    readonly property string icon: {
        const c = root.code, day = new Date().getHours() >= 6 && new Date().getHours() < 18;
        if (c === 0 || c === 1)
            return day ? "clear_day" : "clear_night";
        if (c === 2)
            return day ? "partly_cloudy_day" : "partly_cloudy_night";
        if (c === 45 || c === 48)
            return "foggy";
        if (c >= 95)
            return "thunderstorm";
        if ((c >= 71 && c <= 77) || c === 85 || c === 86)
            return "weather_snowy";
        if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82))
            return "rainy";
        return "cloud";
    }
    property var conf: ({})

    FileView {
        path: Quickshell.env("HOME") + "/.config/theme/weather.json"
        printErrors: false
        onLoaded: {
            try {
                root.conf = JSON.parse(text());
            } catch (e) {
                root.conf = {};
            }
        }
    }

    Feed {
        id: feed
        name: "weather"
        onChanged: root.parse()
    }
    Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: root.parse()
    }

    // The current hour in the forecast's own local clock, interpolated by the minutes past it.
    function parse() {
        const data = feed.data;
        const hr = data ? data.hourly : null;
        if (!hr || !hr.time || !hr.time.length)
            return;
        const now = new Date();
        const pad = n => ("0" + n).slice(-2);
        const key = now.getFullYear() + "-" + pad(now.getMonth() + 1) + "-" + pad(now.getDate()) + "T" + pad(now.getHours()) + ":00";
        let i = hr.time.indexOf(key);
        if (i < 0)
            i = Math.max(0, hr.time.filter(t => t <= key).length - 1);
        const f = now.getMinutes() / 60;
        const at = a => a ? (a[i + 1] === undefined || a[i + 1] === null ? a[i] : a[i] + (a[i + 1] - a[i]) * f) : NaN;
        root.temp = Math.round(at(hr.temperature_2m));
        root.feels = Math.round(at(hr.apparent_temperature));
        root.code = hr.weather_code[i];
        const dy = data.daily;
        const d = dy && dy.time ? dy.time.indexOf(key.slice(0, 10)) : -1;
        if (d >= 0) {
            root.high = Math.round(dy.temperature_2m_max[d]);
            root.low = Math.round(dy.temperature_2m_min[d]);
            root.rain = dy.precipitation_probability_max[d];
        }
        const at0 = feed.updatedAt ? new Date(feed.updatedAt * 1000) : null;
        root.issued = at0 ? pad(at0.getHours()) + ":" + pad(at0.getMinutes()) : "";
    }
}

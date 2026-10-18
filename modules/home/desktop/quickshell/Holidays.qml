pragma Singleton
// The calendar's DATA MODEL: the holiday registry Nix expanded into ~/.config/theme/calendar.json
// (modules/home/desktop/calendar), read once and re-read when a rebuild rewrites it. Filters and
// queries only; the legal rules live in the registry. docs/notes/desktop/calendar.md
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    property var data: null // {years: {"2026": [occurrence...]}, range, jurisdictions, sources}
    readonly property bool loaded: root.data !== null
    readonly property var range: root.loaded ? root.data.range : [0, 0]
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.config/theme/calendar.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(file.text());
            } catch (e) {
                root.data = null;
            }
        }
    }

    // ── Filters: WHERE (scope) and WHAT (class), independent. The defaults: the three places that
    // hold in São Carlos, holidays and optional days; the UN's observances off, they are many. ──
    readonly property var defaults: ({
            sc: true,
            sp: true,
            br: true,
            un: false,
            holiday: true,
            optional: true,
            observance: false
        })
    property var filters: Object.assign({}, root.defaults)
    readonly property bool isDefault: Object.keys(root.defaults).every(k => root.filters[k] === root.defaults[k])
    function toggle(k) {
        const f = Object.assign({}, root.filters);
        f[k] = !f[k];
        root.filters = f; // reassigned, never mutated: bindings only wake on a new object
    }
    function resetFilters() {
        root.filters = Object.assign({}, root.defaults);
    }

    function scopeOf(o) {
        return o.jurisdiction === "BR-SP-SAO-CARLOS" ? "sc" : (o.jurisdiction === "BR-SP" ? "sp" : (o.jurisdiction === "UN" ? "un" : "br"));
    }
    function classOf(o) {
        return o.kind === "observance" ? "observance" : ((o.kind === "optional" || o.kind === "optional_partial") ? "optional" : "holiday");
    }
    function passes(o, f) {
        return f[root.scopeOf(o)] === true && f[root.classOf(o)] === true;
    }

    // One year's occurrences by "MM-DD", after the filters. Recomputed when the year or a filter
    // changes, never per frame; the popover binds to the result.
    function mapFor(year, f) {
        const out = ({});
        const list = root.loaded ? (root.data.years["" + year] || []) : [];
        for (const o of list) {
            if (!root.passes(o, f))
                continue;
            const k = o.date.slice(5);
            if (!out[k])
                out[k] = [];
            out[k].push(o);
        }
        return out;
    }
    function hasYear(year) {
        return root.loaded && root.data.years["" + year] !== undefined;
    }

    // The strongest event of a day, for a cell's main signal: a holiday for everyone first, then a
    // restricted holiday, then an optional day, then an observance.
    function primary(list) {
        if (!list || list.length === 0)
            return null;
        const rank = o => (root.classOf(o) === "holiday" ? (o.applicability.indexOf("general") >= 0 ? 0 : 1) : (root.classOf(o) === "optional" ? 2 : 3));
        let best = list[0];
        for (const o of list)
            if (rank(o) < rank(best))
                best = o;
        return best;
    }

    // The next events from a civil date (y, m, d), across the year's turn, after the filters.
    function upcoming(y, m, d, n, f) {
        const today = y + "-" + ("0" + m).slice(-2) + "-" + ("0" + d).slice(-2);
        const out = [];
        for (const yr of [y, y + 1]) {
            const list = root.loaded ? (root.data.years["" + yr] || []) : [];
            for (const o of list) {
                if (o.date >= today && root.passes(o, f))
                    out.push(o);
                if (out.length >= n)
                    return out;
            }
        }
        return out;
    }

    // Civil-date arithmetic in UTC days: no time of day, so no DST hour can turn 1 day into 0.
    function dayNumber(iso) {
        return Math.round(Date.UTC(+iso.slice(0, 4), +iso.slice(5, 7) - 1, +iso.slice(8, 10)) / 86400000);
    }
    function daysBetween(fromIso, toIso) {
        return root.dayNumber(toIso) - root.dayNumber(fromIso);
    }
    function source(id) {
        return root.loaded ? (root.data.sources[id] || null) : null;
    }

    // ── Words for the UI, in one place ──
    readonly property var scopeNames: ({
            sc: "São Carlos",
            sp: "São Paulo",
            br: "Brasil",
            un: "International"
        })
    function kindWord(o) {
        return ({
                civil_holiday: "Civil holiday",
                religious_holiday: "Religious holiday",
                optional: "Optional day",
                optional_partial: "Optional day, partial",
                observance: "Observance"
            })[o.kind] || o.kind;
    }
    function forWhom(o) {
        const w = {
            general: "Everyone",
            federal_admin: "Federal public administration",
            state_admin: "State public administration",
            municipal_admin: "Municipal public administration",
            municipal_education: "Municipal school network",
            observance: "No day off (observance)"
        };
        return o.applicability.map(a => w[a] || a).join(", ");
    }
    function partialWord(p) {
        return !p ? "" : (p.until ? "until " + p.until : (p.after ? "after " + p.after : ""));
    }
    function statusWord(s) {
        return ({
                verified: "Verified",
                calculated: "Calculated date",
                pending: "Pending its annual act",
                stale: "Source out of date",
                disputed: "Sources disagree"
            })[s] || s;
    }
}

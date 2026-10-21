// The quote rules, ported from the old renderer: validate an entry, fit it to the measure, pick one
// the lock has not shown. Pure functions, no Quickshell imports, so qmltestrunner can test them.
import QtQml

QtObject {
    readonly property var kinds: ["stoic", "literature", "haiku", "computing"]
    readonly property var langs: ["pt", "la", "grc", "ja", "en"]

    // Columns as the eye counts them: East Asian wide and full-width characters take two.
    function columns(text) {
        let n = 0;
        for (const ch of text)
            n += /[ᄀ-ᅟ⺀-꓏가-힣豈-﫿︰-﹏＀-｠￠-￦]/.test(ch) ? 2 : 1;
        return n;
    }

    // Greedy word wrap by columns; null when it does not fit in maxLines (pick another).
    function wrap(text, width, maxLines) {
        const lines = [];
        let cur = "";
        for (const word of text.split(/\s+/).filter(w => w)) {
            if (columns(word) > width)
                return null;
            const cand = cur ? cur + " " + word : word;
            if (columns(cand) <= width) {
                cur = cand;
            } else {
                lines.push(cur);
                cur = word;
            }
        }
        if (cur)
            lines.push(cur);
        return lines.length > 0 && lines.length <= maxLines ? lines : null;
    }

    // Verse keeps its own breaks; each line must fit as it is (a poem is not re-flowed).
    function wrapVerse(text, width, maxLines) {
        const lines = text.split("\n").map(x => x.trim()).filter(x => x);
        if (!lines.length || lines.length > maxLines || lines.some(x => columns(x) > width))
            return null;
        return lines;
    }

    function valid(q) {
        const s = k => typeof q[k] === "string" && q[k].trim() !== "";
        return !!q && typeof q === "object" && s("id") && s("text") && s("author") && kinds.indexOf(q.kind) >= 0 && langs.indexOf(q.lang) >= 0;
    }

    // One entry laid out for the measure m = {columns, lines, originalColumns, originalLines}:
    // {id, lines, verse, original, lang, credit}, or null when it does not fit.
    function format(q, m) {
        if (!valid(q))
            return null;
        const text = q.text.trim();
        const verse = q.kind === "haiku" || text.indexOf("\n") >= 0;
        const body = verse ? wrapVerse(text, m.columns, m.lines) : wrap("“" + text + "”", m.columns, m.lines);
        if (!body)
            return null;
        let original = [];
        const o = q.lang !== "pt" && typeof q.original === "string" ? q.original.trim() : "";
        if (o) {
            original = o.indexOf("\n") >= 0 ? wrapVerse(o, m.originalColumns, m.originalLines) : wrap(o, m.originalColumns, m.originalLines);
            if (!original)
                return null;
        }
        // The credit drops the year, then the source, before it would overflow.
        const parts = [q.author.trim()].concat(["source", "year"].filter(k => typeof q[k] === "string" && q[k].trim()).map(k => q[k].trim()));
        while (parts.length > 1 && columns(parts.join(" · ")) > m.originalColumns)
            parts.pop();
        return { id: q.id, lines: body, verse: verse, original: original, lang: q.lang, credit: parts.join(" · ") };
    }

    // An entry not shown yet: haiku only beside a print (haikuOk), about one draw in `share` then;
    // the history resets once everything was seen, never repeating the last one. random() is
    // injected so a test can fix it. Returns {quote, seen} (the history to store), or the fallback.
    function choose(pool, seen, haikuOk, share, m, fallback, random) {
        const ok = pool.filter(q => valid(q) && (haikuOk || q.kind !== "haiku"));
        let hist = (seen || []).filter(i => typeof i === "string");
        let fresh = ok.filter(q => hist.indexOf(q.id) < 0);
        if (!fresh.length) {
            hist = hist.slice(-1);
            fresh = ok.filter(q => hist.indexOf(q.id) < 0);
        }
        const shuffle = a => {
            for (let i = a.length - 1; i > 0; i--) {
                const j = Math.floor(random() * (i + 1));
                [a[i], a[j]] = [a[j], a[i]];
            }
            return a;
        };
        const haiku = shuffle(fresh.filter(q => q.kind === "haiku"));
        const rest = shuffle(fresh.filter(q => q.kind !== "haiku"));
        const first = haiku.length && (!rest.length || random() < share) ? haiku : rest;
        const order = first.concat(haiku.concat(rest).filter(q => first.indexOf(q) < 0));
        for (const q of order) {
            const f = format(q, m);
            if (f)
                return { quote: f, seen: hist.concat([q.id]) };
        }
        return { quote: format(fallback, m), seen: hist };
    }
}

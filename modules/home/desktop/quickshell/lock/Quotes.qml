// The lock's quote: one entry of the curated collection (lockscreen/quotes.json, content in the
// repo) not shown yet, laid out for the measure. What was shown is STATE, in the history file.
import Quickshell
import Quickshell.Io
import QtQuick

Scope {
    id: quotes

    property string file: Quickshell.env("LOCK_QUOTES") || ""
    property string historyFile: Quickshell.env("LOCK_STATE") ? Quickshell.env("LOCK_STATE") + "/quotes-seen.json" : ""
    property bool haikuOk: false // only beside a print with an artist: a haiku needs its picture
    property bool armed: false // set once the print is known, so the haiku rule sees it
    property var measure: ({
            columns: 64,
            lines: 3,
            originalColumns: 90,
            originalLines: 2
        })
    property real haikuShare: 0.34
    property var quote: null // {id, lines, verse, original, lang, credit}
    readonly property var fallback: ({
            id: "kay-predict-the-future",
            kind: "computing",
            text: "A melhor forma de prever o futuro é inventá-lo.",
            original: "The best way to predict the future is to invent it.",
            lang: "en",
            author: "Alan Kay",
            source: "reunião no Xerox PARC",
            year: "1971"
        })

    QuoteMath {
        id: math
    }

    function pick() {
        let pool = [], seen = [];
        try {
            pool = JSON.parse(collection.text() || "[]");
        } catch (e) {}
        try {
            seen = JSON.parse(history.text() || "[]");
        } catch (e) {}
        const r = math.choose(Array.isArray(pool) ? pool : [], Array.isArray(seen) ? seen : [], quotes.haikuOk, quotes.haikuShare, quotes.measure, quotes.fallback, Math.random);
        quotes.quote = r.quote;
        if (quotes.historyFile && r.quote && r.quote.id !== quotes.fallback.id)
            history.setText(JSON.stringify(r.seen));
    }
    onArmedChanged: if (quotes.armed && !quotes.quote)
        quotes.pick()

    FileView {
        id: collection
        path: quotes.file
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: history
        path: quotes.historyFile
        blockLoading: true
        printErrors: false
    }
}

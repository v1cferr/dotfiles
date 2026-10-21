// QuoteMath: the collection's rules (validity, the fit, no repeat until exhausted, haiku pairing).
import QtQuick
import QtTest
import "../lock"

TestCase {
    name: "Quotes"

    QuoteMath {
        id: m
    }
    readonly property var measure: ({
            columns: 40,
            lines: 3,
            originalColumns: 60,
            originalLines: 2
        })
    function entry(id, kind, text) {
        return {
            id: id,
            kind: kind,
            lang: "pt",
            text: text || "Uma frase curta.",
            author: "Autor"
        };
    }
    function seq(values) {
        let i = 0;
        return () => values[i++ % values.length];
    }

    function test_columns() {
        compare(m.columns("abc"), 3);
        compare(m.columns("春の海"), 6, "East Asian wide characters take two");
    }
    function test_wrap() {
        compare(m.wrap("um dois tres", 7, 2), ["um dois", "tres"]);
        compare(m.wrap("um dois tres quatro", 7, 2), null, "past maxLines it does not fit");
        compare(m.wrapVerse("a\nb\nc", 5, 3), ["a", "b", "c"], "verse keeps its breaks");
    }
    function test_valid() {
        verify(m.valid(entry("a", "stoic")));
        verify(!m.valid(entry("a", "gossip")), "an unknown kind is refused");
        verify(!m.valid({ id: "a", kind: "stoic", lang: "pt", text: "x" }), "an author is required");
    }
    function test_format() {
        const f = m.format({ id: "x", kind: "computing", lang: "en", text: "Curta.", original: "Short.", author: "A", source: "S", year: "1971" }, measure);
        compare(f.lines, ["“Curta.”"]);
        compare(f.original, ["Short."]);
        compare(f.credit, "A · S · 1971");
        const pt = m.format({ id: "y", kind: "literature", lang: "pt", text: "Texto.", original: "ignored", author: "B" }, measure);
        compare(pt.original, [], "a Portuguese text shows no original");
    }
    function test_credit_drops_year_then_source() {
        const f = m.format({ id: "x", kind: "stoic", lang: "pt", text: "T.", author: "Autor", source: "Uma fonte bem longa demais para caber", year: "c. 170" }, { columns: 40, lines: 3, originalColumns: 20, originalLines: 2 });
        compare(f.credit, "Autor");
    }
    function test_no_repeat_until_exhausted() {
        const pool = [entry("a", "stoic"), entry("b", "stoic")];
        const one = m.choose(pool, ["a"], false, 0.34, measure, entry("fb", "computing"), seq([0.1]));
        compare(one.quote.id, "b", "the unseen one");
        compare(one.seen, ["a", "b"]);
        const reset = m.choose(pool, ["a", "b"], false, 0.34, measure, entry("fb", "computing"), seq([0.1]));
        compare(reset.quote.id, "a", "after a reset, never the last one shown");
        compare(reset.seen, ["b", "a"]);
    }
    function test_haiku_only_beside_a_print() {
        const pool = [entry("h", "haiku", "a\nb\nc")];
        const none = m.choose(pool, [], false, 1, measure, entry("fb", "computing"), seq([0]));
        compare(none.quote.id, "fb", "no artist, no haiku: the fallback");
        const yes = m.choose(pool, [], true, 1, measure, entry("fb", "computing"), seq([0]));
        compare(yes.quote.id, "h");
        compare(yes.quote.verse, true);
    }
    function test_too_long_is_skipped() {
        const pool = [entry("long", "stoic", "palavra ".repeat(60)), entry("ok", "stoic")];
        compare(m.choose(pool, [], false, 0, measure, entry("fb", "computing"), seq([0])).quote.id, "ok");
    }
}

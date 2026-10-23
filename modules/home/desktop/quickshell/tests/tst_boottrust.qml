// BootTrustMath: no green without evidence, unknown stays unknown.
import QtQuick
import QtTest
import "../data"

TestCase {
    name: "BootTrust"

    BootTrustMath {
        id: m
    }
    function full(over) {
        return Object.assign({
            secureBoot: "on",
            setupMode: "user",
            loader: {
                configured: "limine",
                running: "Limine 12.5.2",
                signed: "valid"
            },
            integrity: "enrolled",
            thisBoot: "verified"
        }, over || {});
    }

    function test_no_record_is_unknown_everywhere() {
        const c = m.cards(null);
        compare(c.length, 3);
        verify(c.every(x => x.tone === "unknown"));
    }
    function test_full_chain_is_green() {
        verify(m.cards(full()).every(x => x.tone === "ok"));
    }
    function test_setup_mode_is_not_green() {
        compare(m.secureBoot(full({
            setupMode: "setup"
        })).tone, "warn");
    }
    function test_grub_today_is_partial() {
        const c = m.cards(full({
            loader: {
                configured: "grub",
                running: "unknown",
                signed: "valid"
            },
            integrity: "kernel-only",
            thisBoot: "unknown"
        }));
        compare(c[1].tone, "ok");
        compare(c[1].caption, "grub, not self-reported");
        compare(c[2].value, "Partial");
        compare(c[2].tone, "warn");
    }
    function test_enrolled_without_proof_of_this_boot() {
        compare(m.integrity(full({
            thisBoot: "unknown"
        })).tone, "warn");
    }
    function test_failures_are_red() {
        compare(m.loader(full({
            loader: {
                signed: "invalid"
            }
        })).tone, "crit");
        compare(m.integrity(full({
            integrity: "mismatch"
        })).tone, "crit");
        compare(m.secureBoot(full({
            secureBoot: "off"
        })).tone, "crit");
    }
    function test_every_card_explains_itself() {
        for (const c of m.cards(null))
            verify(m.explain(c.label).length > 20, c.label);
    }
    function test_garbage_is_unknown() {
        const c = m.cards({
            secureBoot: "maybe"
        });
        verify(c.every(x => x.tone === "unknown"));
    }
}

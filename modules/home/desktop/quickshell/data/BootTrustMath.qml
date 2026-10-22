// boot-trust's JSON into the NixOS Center's three BOOT cards. Pure functions, no Quickshell
// imports, so qmltestrunner can test them. A tone of "ok" needs evidence: docs/notes/boot-and-storage/boot.md
import QtQml

QtObject {
    // tone: ok | warn | crit | unknown, mapped to Theme's state colors by the section.
    function card(label, value, tone, caption) {
        return {
            label: label,
            value: value,
            tone: tone,
            caption: caption
        };
    }

    function cards(t) {
        if (!t)
            return [card("SECURE BOOT", "Unknown", "unknown", "boot-trust has not run"), card("LOADER", "Unknown", "unknown", "no record"), card("INTEGRITY", "Unknown", "unknown", "no record")];
        return [secureBoot(t), loader(t), integrity(t)];
    }

    function secureBoot(t) {
        if (t.secureBoot === "on")
            return t.setupMode === "user" ? card("SECURE BOOT", "On", "ok", "firmware in user mode") : card("SECURE BOOT", "On", "warn", t.setupMode === "setup" ? "setup mode: keys are open" : "mode unknown");
        if (t.secureBoot === "off")
            return card("SECURE BOOT", "Off", "crit", "the firmware verifies nothing");
        return card("SECURE BOOT", "Unknown", "unknown", "firmware did not say");
    }

    function loader(t) {
        const l = t.loader || {};
        const who = l.running && l.running !== "unknown" ? l.running : (l.configured || "?") + ", not self-reported";
        switch (l.signed) {
        case "valid":
            return card("LOADER", "Signed", "ok", who);
        case "invalid":
            return card("LOADER", "Unsigned", "crit", "the firmware will refuse it");
        case "missing":
            return card("LOADER", "Missing", "crit", "no binary on the ESP");
        }
        return card("LOADER", "Unknown", "unknown", who);
    }

    function integrity(t) {
        switch (t.integrity) {
        case "enrolled":
            return t.thisBoot === "verified" ? card("INTEGRITY", "Verified", "ok", "kernel, initrd and cmdline") : card("INTEGRITY", "Enrolled", "warn", "this boot is not proven");
        case "kernel-only":
            return card("INTEGRITY", "Partial", "warn", "initrd not verified");
        case "mismatch":
            return card("INTEGRITY", "Mismatch", "crit", "config differs from the enrolled hash");
        }
        return card("INTEGRITY", "Unknown", "unknown", "no evidence either way");
    }
}

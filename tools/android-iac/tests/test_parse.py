"""The parsers, the allowlist and the redaction, against synthetic adb output."""

from __future__ import annotations

import json
import unittest

import parse
import sanitize
from adb import Adb, Refused, allowed
from fake import FakeAdb, fixture, healthy


class Parsers(unittest.TestCase):
    def test_devices_skip_daemon_noise_and_drop_the_serial(self) -> None:
        (d,) = parse.devices(fixture("devices-one.txt"))
        self.assertEqual((d.state, d.transport, d.transport_id), ("device", "tcp", "4"))
        self.assertNotIn("192.168.1.31:40123", repr(d))

    def test_devices_none_unauthorized_and_two(self) -> None:
        self.assertEqual(parse.devices(fixture("devices-none.txt")), [])
        (u,) = parse.devices(fixture("devices-unauthorized.txt"))
        self.assertEqual((u.state, u.transport), ("unauthorized", "usb"))
        self.assertEqual([d.transport_id for d in parse.devices(fixture("devices-two.txt"))], ["2", "3"])

    def test_getprop_ignores_noise_and_broken_lines(self) -> None:
        props = parse.getprop(fixture("getprop.txt"))
        self.assertEqual(props["ro.build.version.sdk"], "36")
        self.assertNotIn("ro.broken.multiline", props)

    def test_settings_and_unset_values(self) -> None:
        self.assertIsNone(parse.setting("null\n"))
        self.assertIsNone(parse.setting(None))
        self.assertEqual(parse.setting(" 1\n"), "1")
        listed = parse.settings_list(fixture("settings-global.txt"))
        self.assertEqual(listed["auto_time"], "1")
        self.assertNotIn("", listed)

    def test_small_reads(self) -> None:
        self.assertEqual(parse.selinux("Enforcing\n"), "Enforcing")
        self.assertIsNone(parse.selinux("/system/bin/sh: getenforce: inaccessible"))
        self.assertEqual(parse.nfc(fixture("dumpsys-nfc.txt")), "on")
        self.assertIsNone(parse.nfc(""))
        self.assertIs(parse.lock_disabled("false\n"), False)
        self.assertIsNone(parse.lock_disabled("Error: something"))

    def test_runtime_permissions_only_granted_ones(self) -> None:
        got = parse.granted_runtime(fixture("dumpsys-package.txt"))
        self.assertEqual(got, {"android.permission.RECORD_AUDIO", "android.permission.POST_NOTIFICATIONS"})


class Allowlist(unittest.TestCase):
    def test_reads_pass(self) -> None:
        for args in healthy():
            self.assertTrue(allowed(args), args)

    def test_writes_and_injection_are_refused_before_running(self) -> None:
        refused = [
            ("shell", "settings", "put", "global", "adb_enabled", "0"),
            ("shell", "pm", "disable-user", "com.android.vending"),
            ("shell", "pm", "uninstall", "--user", "0", "com.example"),
            ("shell", "reboot"), ("reboot", "bootloader"), ("install", "x.apk"),
            ("shell", "settings", "get", "global", "x; rm -rf /sdcard"),
            ("shell", "dumpsys", "package", "com.x && reboot"),
            ("shell", "pm", "list", "packages", "-e", "-d"),
            ("shell", "settings", "list", "global", "extra"),
            ("shell", "su", "-c", "id"),
        ]
        fake = FakeAdb({})
        adb = Adb(fake)
        for args in refused:
            self.assertFalse(allowed(args), args)
            with self.assertRaises(Refused):
                adb.call(*args)
        self.assertEqual(fake.calls, [])


class Redaction(unittest.TestCase):
    def test_props_keep_only_the_allowlist(self) -> None:
        kept = sanitize.props(parse.getprop(fixture("getprop.txt")))
        dumped = json.dumps(kept)
        for secret in ("ZY22SYNTHETIC", "356938035643809", "02:00:5e:10:00:01", "someone@example.com"):
            self.assertNotIn(secret, dumped)
        self.assertEqual(kept["ro.boot.verifiedbootstate"], "green")

    def test_settings_redact_identity_keys_and_free_text(self) -> None:
        clean = sanitize.settings(parse.settings_list(fixture("settings-global.txt")))
        self.assertEqual(clean["auto_time"], "1")
        for key in ("device_name", "bluetooth_address", "wifi_ssid", "some_flag"):
            self.assertEqual(clean[key], sanitize.REDACTED, key)
        self.assertEqual(sanitize.setting_value("enabled_accessibility_services", "com.x/.Svc"), "com.x/.Svc")

    def test_the_last_net_catches_a_new_field(self) -> None:
        out = sanitize.deep_scrub({"new": ["imei 356938035643809", "mac 02:00:5E:10:00:02", "a@b.io"]})
        self.assertNotIn("356938035643809", json.dumps(out))
        self.assertNotIn("02:00:5E", json.dumps(out))
        self.assertNotIn("a@b.io", json.dumps(out))


if __name__ == "__main__":
    unittest.main()

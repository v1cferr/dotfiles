#!/usr/bin/env python3
"""The registry's tests: the computus, civil-date arithmetic, the schema rules, and the 2026
audit against the acts as read on 18/10/2026. Run: python3 -m unittest discover -s scripts"""

import datetime as dt
import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch
from types import SimpleNamespace

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import registry as r  # noqa: E402

REG = r.load(HERE.parent / "registry")
D = dt.date


def on(year, iso, **match):
    """The occurrences on a date, narrowed by field equality (applicability: one member)."""
    out = []
    for o in r.expand(REG, year):
        if o["date"] != iso:
            continue
        ok = True
        for k, v in match.items():
            if k == "applicability":
                ok &= v in o["applicability"]
            else:
                ok &= o[k] == v
        if ok:
            out.append(o)
    return out


class Computus(unittest.TestCase):
    # Western Easter Sundays from published tables.
    KNOWN = {
        2000: D(2000, 4, 23),
        2019: D(2019, 4, 21),
        2024: D(2024, 3, 31),
        2025: D(2025, 4, 20),
        2026: D(2026, 4, 5),
        2027: D(2027, 3, 28),
        2028: D(2028, 4, 16),
        2038: D(2038, 4, 25),
    }

    def test_known_easters(self):
        for y, d in self.KNOWN.items():
            self.assertEqual(r.easter(y), d, y)

    def test_carnaval_crosses_a_leap_february(self):
        # 2028 is a leap year: Easter 16/04 puts Carnaval's Tuesday on 29/02.
        days = [o["date"] for o in r.expand(REG, 2028) if o["id"].startswith("br-fed-carnaval")]
        self.assertEqual(days, ["2028-02-28", "2028-02-29"])

    def test_carnaval_2024_and_2027(self):
        self.assertEqual(r.easter(2024) - dt.timedelta(days=48), D(2024, 2, 12))
        self.assertEqual(r.easter(2027) - dt.timedelta(days=47), D(2027, 2, 9))

    def test_corpus_christi(self):
        self.assertEqual(on(2026, "2026-06-04", id="sc-corpus-christi")[0]["kind"], "religious_holiday")
        self.assertEqual(on(2027, "2027-05-27", id="sc-corpus-christi")[0]["status"], "calculated")

    def test_fixed_29_february_never_shifts(self):
        ev = {"id": "x", "rule": {"type": "fixed", "month": 2, "day": 29}}
        self.assertEqual(r.dates_of(ev, 2028), [D(2028, 2, 29)])
        self.assertEqual(r.dates_of(ev, 2027), [])

    def test_range_crosses_the_year(self):
        ev = {"id": "x", "rule": {"type": "range", "start": "2026-12-30", "end": "2027-01-02"}}
        self.assertEqual(r.dates_of(ev, 2026), [D(2026, 12, 30), D(2026, 12, 31)])
        self.assertEqual(r.dates_of(ev, 2027), [D(2027, 1, 1), D(2027, 1, 2)])


class Schema(unittest.TestCase):
    def test_registry_validates(self):
        self.assertEqual(r.validate(REG), [])

    def test_rules_reject_blurred_kinds(self):
        bad = json.loads(json.dumps(REG))
        bad["events"].append(
            {
                "id": "t-optional-general",
                "name": "x",
                "jurisdiction": "BR",
                "kind": "optional",
                "applicability": ["general"],
                "rule": {"type": "date", "date": "2026-01-02"},
                "status": "verified",
                "verified_at": "2026-10-18",
                "sources": ["br-lei-662-1949"],
            }
        )
        bad["events"].append(
            {
                "id": "t-un-holiday",
                "name": "x",
                "jurisdiction": "UN",
                "kind": "civil_holiday",
                "applicability": ["general"],
                "rule": {"type": "date", "date": "2026-01-03"},
                "status": "verified",
                "verified_at": "2099-01-01",
                "sources": ["un-observances"],
            }
        )
        errs = " | ".join(r.validate(bad, today=D(2026, 10, 18)))
        self.assertIn("never applies to the general population", errs)
        self.assertIn("never a Brazilian holiday", errs)
        self.assertIn("verified_at in the future", errs)


class Audit2026(unittest.TestCase):
    """Portaria 2083/2025 (São Carlos), item by item: (date, kind, jurisdiction, applicability)."""

    PORTARIA_2083 = [
        ("2026-02-16", "optional", "BR-SP-SAO-CARLOS", "municipal_admin"),
        ("2026-02-17", "optional", "BR-SP-SAO-CARLOS", "municipal_admin"),
        ("2026-02-18", "optional_partial", "BR-SP-SAO-CARLOS", "municipal_admin"),
        ("2026-04-03", "religious_holiday", "BR-SP-SAO-CARLOS", "general"),
        ("2026-04-20", "optional", "BR-SP-SAO-CARLOS", "municipal_admin"),
        ("2026-04-21", "civil_holiday", "BR", "general"),
        ("2026-05-01", "civil_holiday", "BR", "general"),
        ("2026-06-04", "religious_holiday", "BR-SP-SAO-CARLOS", "general"),
        ("2026-06-05", "optional", "BR-SP-SAO-CARLOS", "municipal_admin"),
        ("2026-07-09", "civil_holiday", "BR-SP", "general"),
        ("2026-07-10", "optional", "BR-SP-SAO-CARLOS", "municipal_admin"),
        ("2026-08-15", "religious_holiday", "BR-SP-SAO-CARLOS", "general"),
        ("2026-09-07", "civil_holiday", "BR", "general"),
        ("2026-10-12", "civil_holiday", "BR", "general"),
        ("2026-10-15", "civil_holiday", "BR-SP-SAO-CARLOS", "municipal_education"),
        ("2026-10-28", "optional", "BR-SP-SAO-CARLOS", "municipal_admin"),
        ("2026-11-02", "civil_holiday", "BR", "general"),
        ("2026-11-03", "optional", "BR-SP-SAO-CARLOS", "municipal_admin"),
        ("2026-11-04", "religious_holiday", "BR-SP-SAO-CARLOS", "general"),
        ("2026-11-15", "civil_holiday", "BR", "general"),
        ("2026-11-20", "civil_holiday", "BR", "general"),
        ("2026-12-24", "optional", "BR-SP-SAO-CARLOS", "municipal_admin"),
        ("2026-12-25", "civil_holiday", "BR", "general"),
        ("2026-12-31", "optional", "BR-SP-SAO-CARLOS", "municipal_admin"),
    ]

    def test_every_item_of_portaria_2083(self):
        for iso, kind, jur, appl in self.PORTARIA_2083:
            hits = on(2026, iso, kind=kind, jurisdiction=jur, applicability=appl)
            self.assertEqual(len(hits), 1, f"{iso} {kind} {jur} {appl}")
            self.assertEqual(hits[0]["status"], "verified", iso)

    def test_item_xxv_new_year_2027(self):
        self.assertEqual(len(on(2027, "2027-01-01", id="br-confraternizacao")), 1)

    def test_partial_hours_differ_by_act(self):
        self.assertEqual(on(2026, "2026-02-18", id="sc-mun-cinzas")[0]["partial"], {"until": "12:00"})
        self.assertEqual(on(2026, "2026-02-18", id="br-fed-cinzas")[0]["partial"], {"until": "14:00"})
        self.assertEqual(on(2026, "2026-12-24", id="br-fed-vespera-natal-2026")[0]["partial"], {"after": "13:00"})

    def test_good_friday_keeps_both_sources(self):
        o = on(2026, "2026-04-03", id="sc-paixao-de-cristo")[0]
        self.assertIn("br-portaria-mgi-11460-2025", o["sources"])
        self.assertIn("sc-portaria-2083-2025", o["sources"])

    def test_corpus_christi_two_records_one_day(self):
        kinds = sorted(o["kind"] for o in on(2026, "2026-06-04") if "Corpus" in o["name"])
        self.assertEqual(kinds, ["optional", "religious_holiday"])

    def test_teachers_day_is_restricted(self):
        o = on(2026, "2026-10-15", id="sc-dia-do-professor-2026")[0]
        self.assertEqual(o["applicability"], ["municipal_education"])

    def test_14_general_holidays_in_sao_carlos(self):
        # The count the city publishes: the general holidays that hold in São Carlos in 2026.
        n = [o for o in r.expand(REG, 2026) if o["kind"] in r.HOLIDAY_KINDS and "general" in o["applicability"]]
        self.assertEqual(len(n), 14, [o["id"] for o in n])


class FutureYears(unittest.TestCase):
    def test_no_optional_day_is_assumed(self):
        o = on(2027, "2027-02-08", id="br-fed-carnaval-segunda")[0]
        self.assertEqual(o["status"], "pending")
        self.assertEqual([x for x in r.expand(REG, 2027) if x["id"] == "sc-mun-2026-07-10"], [])

    def test_consciencia_negra_from_2024(self):
        self.assertEqual(on(2023, "2023-11-20", id="br-consciencia-negra"), [])
        self.assertEqual(len(on(2024, "2024-11-20", id="br-consciencia-negra")), 1)

    def test_year_turn(self):
        last = [o["date"] for o in r.expand(REG, 2026)][-1]
        first = [o["date"] for o in r.expand(REG, 2027)][0]
        self.assertTrue(last.startswith("2026-12") and first.startswith("2027-01"))

    def test_observances_only_for_the_year_read(self):
        self.assertTrue(any(o["jurisdiction"] == "UN" for o in r.expand(REG, 2026)))
        self.assertFalse(any(o["jurisdiction"] == "UN" for o in r.expand(REG, 2027)))


class Build(unittest.TestCase):
    def test_build_is_json_and_ordered(self):
        b = r.build(REG, 2025, 2027)
        self.assertEqual(sorted(b["years"]), ["2025", "2026", "2027"])
        dates = [o["date"] for o in b["years"]["2026"]]
        self.assertEqual(dates, sorted(dates))
        json.dumps(b)


class SourceWatch(unittest.TestCase):
    def test_new_source_needs_review(self):
        reg = {"sources": {"new": {"url": "https://example.org/official", "watch": True}}}
        with patch.object(r, "fetch", return_value=b"<p>Official dates</p>"):
            lock, report = r.check_sources(reg, {}, "2026-10-18")
        self.assertEqual(report[0]["state"], "new")
        self.assertIn("new", lock)
        self.assertTrue(r.review_needed(report))

    def test_unchanged_source_is_quiet(self):
        body = b"<p>Official dates</p>"
        reg = {"sources": {"official": {"url": "https://example.org/official", "watch": True}}}
        prev = {"official": {"fingerprint": r.fingerprint(body), "seen_at": "2026-10-17"}}
        with patch.object(r, "fetch", return_value=body):
            lock, report = r.check_sources(reg, prev, "2026-10-18")
        self.assertEqual(report[0]["state"], "unchanged")
        self.assertEqual(lock["official"]["seen_at"], "2026-10-17")
        self.assertFalse(r.review_needed(report))

    def test_unreachable_keeps_previous_baseline(self):
        reg = {"sources": {"official": {"url": "https://example.org/official", "watch": True}}}
        prev = {"official": {"fingerprint": "sha256:baseline", "seen_at": "2026-10-17"}}
        with patch.object(r, "fetch", side_effect=RuntimeError("timeout")):
            lock, report = r.check_sources(reg, prev, "2026-10-18")
        self.assertEqual(report[0]["state"], "unreachable")
        self.assertEqual(lock, prev)
        self.assertTrue(r.review_needed(report))

    def test_aia_certificate_must_validate_before_curl_retry(self):
        """Reject an untrusted AIA issuer without ever retrying using --cacert."""
        calls = []
        leaf = b"-----BEGIN CERTIFICATE-----\\nleaf\\n-----END CERTIFICATE-----"
        issuer = b"-----BEGIN CERTIFICATE-----\\nissuer\\n-----END CERTIFICATE-----"

        def fake_run(command, *args, **kwargs):
            calls.append(command)
            if command[0] == "curl" and "--cacert" not in command:
                if "http://issuer.example/ca.der" in command:
                    return SimpleNamespace(returncode=0, stdout=b"DER", stderr=b"")
                return SimpleNamespace(returncode=60, stdout=b"", stderr=b"untrusted issuer")
            if command[:2] == ["openssl", "s_client"]:
                return SimpleNamespace(returncode=0, stdout=leaf, stderr=b"")
            if command[:3] == ["openssl", "x509", "-noout"]:
                return SimpleNamespace(returncode=0, stdout=b"CA Issuers - URI:http://issuer.example/ca.der", stderr=b"")
            if command[:3] == ["openssl", "x509", "-inform"]:
                return SimpleNamespace(returncode=0, stdout=issuer, stderr=b"")
            if command[:2] == ["openssl", "verify"]:
                self.assertIn("-verify_hostname", command)
                self.assertIn("-untrusted", command)
                self.assertIn("-CAfile", command)
                return SimpleNamespace(returncode=2, stdout=b"", stderr=b"untrusted issuer")
            raise AssertionError(f"Unexpected command: {command!r}")

        # The Nix build sandbox has no /etc/ssl/certs/ca-certificates.crt.
        # The trust-anchor path is a fixture; the OpenSSL failure is what this test exercises.
        with (
            patch.object(r.subprocess, "run", side_effect=fake_run),
            patch.object(r.Path, "exists", return_value=True),
        ):
            with self.assertRaisesRegex(RuntimeError, "could not be verified"):
                r.fetch("https://example.org/official")
        self.assertTrue(any(c[:2] == ["openssl", "verify"] for c in calls))
        self.assertFalse(any("--cacert" in c for c in calls))

    def test_review_needed_changed_source(self):
        self.assertTrue(r.review_needed([{"state": "changed"}]))
        self.assertFalse(r.review_needed([{"state": "unchanged"}]))


if __name__ == "__main__":
    unittest.main()

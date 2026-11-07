"""`android-iac apps`: the installed third-party apps become the local overlay, and nothing else."""

from __future__ import annotations

import contextlib
import io
import json
import stat
import tempfile
import unittest
from pathlib import Path
from typing import Any

import cli
from fake import FakeAdb, healthy, isolate_overlay, spec_file

ENABLED = ("shell", "pm", "list", "packages", "-e")
DISABLED = ("shell", "pm", "list", "packages", "-d")


class Apps(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = Path(tempfile.mkdtemp())
        isolate_overlay(self.tmp)
        self.spec = spec_file(self.tmp)
        self.overlay = self.tmp / "android-iac" / "local.json"

    def run_cli(self, answers: dict[tuple[str, ...], Any], *argv: str) -> tuple[int, str]:
        with contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()):
            code = cli.main(["--spec", self.spec, *argv], FakeAdb(answers))
        return code, out.getvalue()

    def test_prints_without_saving(self) -> None:
        code, out = self.run_cli(healthy(), "apps")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out), {"mustBeInstalled": ["br.example.bank", "org.example.notes"]})
        self.assertFalse(self.overlay.exists())

    def test_save_is_owner_only_keeps_other_keys_and_skips_disabled(self) -> None:
        self.overlay.parent.mkdir()
        self.overlay.write_text(json.dumps({"mustBeInstalled": ["com.example.gone"], "note": "mine"}))
        answers = {**healthy(), ENABLED: "package:br.example.bank\n", DISABLED: "package:org.example.notes\n"}
        code, out = self.run_cli(answers, "apps", "--save")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(self.overlay.read_text()), {"mustBeInstalled": ["br.example.bank"], "note": "mine"})
        self.assertEqual(stat.S_IMODE(self.overlay.stat().st_mode), 0o600)
        self.assertIn("1 new, 1 gone", out)
        self.assertIn("1 disabled third-party apps were left out", out)

    def test_an_unread_list_saves_nothing(self) -> None:
        answers = healthy()
        del answers[("shell", "pm", "list", "packages", "-3")]
        self.assertEqual(self.run_cli(answers, "apps", "--save")[0], 2)
        self.assertFalse(self.overlay.exists())


if __name__ == "__main__":
    unittest.main()

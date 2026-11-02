from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
FIXTURES = ROOT / "tests" / "fixtures"
sys.path.insert(0, str(SCRIPTS))

from validate_skill import classify_fixture  # noqa: E402


class FixtureTests(unittest.TestCase):
    def test_all_fixture_classifications(self) -> None:
        for path in FIXTURES.glob("*.json"):
            with self.subTest(path=path.name):
                document = json.loads(path.read_text(encoding="utf-8"))
                self.assertEqual(
                    document["expected_classification"],
                    classify_fixture(document),
                )

    def test_hy2_return_loss_fixture_matches_script(self) -> None:
        document = json.loads(
            (FIXTURES / "ipv4-udp-return-loss.json").read_text(encoding="utf-8")
        )
        obs = document["observations"]
        result = subprocess.run(
            [
                str(SCRIPTS / "diagnose-hy2.sh"),
                "--family",
                str(obs["family"]),
                "--tiny-request",
                "yes" if obs["request_seen"] else "no",
                "--reply-left",
                "yes" if obs["reply_left"] else "no",
                "--reply-received",
                "yes" if obs["reply_received"] else "no",
                "--csum-before",
                str(obs["checksum_before"]),
                "--csum-after",
                str(obs["checksum_after"]),
            ],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(20, result.returncode, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(document["expected_classification"], report["classification"])


class DiagnosticContractTests(unittest.TestCase):
    def test_report_redacts_addresses_urls_and_credentials(self) -> None:
        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPTS / "report.py"),
                "--tool",
                "test",
                "--status",
                "pass",
                "--check",
                (
                    "redaction|pass|ip=203.0.113.77 "
                    "url=https://vpn.example.invalid/sub/value token=value user=admin"
                ),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        self.assertNotIn("203.0.113.77", result.stdout)
        self.assertNotIn("/sub/value", result.stdout)
        self.assertNotIn("token=value", result.stdout)
        self.assertNotIn("user=admin", result.stdout)
        json.loads(result.stdout)

    def test_conntrack_logger_classifies_and_redacts(self) -> None:
        result = subprocess.run(
            [
                str(SCRIPTS / "vpn-conn-log"),
                "--input",
                str(FIXTURES / "conntrack-events.txt"),
                "--local-address",
                "203.0.113.10",
                "--hy2-port",
                "8444",
                "--reality-port",
                "443",
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        rows = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual(["new", "up", "down", "new", "down"], [r["event"] for r in rows])
        self.assertEqual("closed", rows[2]["result"])
        self.assertEqual("handshake_timeout", rows[4]["result"])
        self.assertNotIn("198.51.100.20", result.stdout)
        self.assertNotIn("198.51.100.30", result.stdout)

    def test_acceptance_without_targets_is_warning(self) -> None:
        result = subprocess.run(
            [str(SCRIPTS / "acceptance.sh")],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(10, result.returncode)
        self.assertEqual("no_acceptance_targets", json.loads(result.stdout)["classification"])

    def test_file_generator_requires_confirmation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "sample.bin"
            result = subprocess.run(
                [
                    str(SCRIPTS / "make-test-file.sh"),
                    "--output",
                    str(destination),
                    "--bytes",
                    "1024",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(20, result.returncode)
            self.assertFalse(destination.exists())
            self.assertEqual(
                "confirmation_required", json.loads(result.stdout)["classification"]
            )


if __name__ == "__main__":
    unittest.main()

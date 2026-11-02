#!/usr/bin/env python3
"""Repository validator for the self-hosted-vpn skill."""

from __future__ import annotations

import ipaddress
import json
import os
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests" / "fixtures"
MARKDOWN_LINK = re.compile(r"!?\[[^\]]*]\(([^)]+)\)")
IPV4 = re.compile(r"(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])")
UUID = re.compile(
    r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\b"
)
SECRET_ASSIGNMENT = re.compile(
    r"(?i)\b(password|passwd|secret|token|private[_ -]?key|authorization)\s*[:=]\s*[\"']?([^\s,\"'}]+)"
)
REQUIRED_FIXTURES = {
    "port-occupied",
    "udp-not-allowed",
    "stale-subscription",
    "double-tun",
    "large-packet-checksum-corruption",
    "ipv4-udp-return-loss",
    "ipv6-logging-blind-spot",
}
DOC_V4 = tuple(
    ipaddress.ip_network(value)
    for value in ("192.0.2.0/24", "198.51.100.0/24", "203.0.113.0/24")
)
DOC_V6 = ipaddress.ip_network("2001:db8::/32")
EXECUTABLES = {
    "scripts/preflight.sh",
    "scripts/diagnose-client-macos.sh",
    "scripts/diagnose-hy2.sh",
    "scripts/diagnose-reality.sh",
    "scripts/acceptance.sh",
    "scripts/make-test-file.sh",
    "scripts/report.py",
    "scripts/udp_echo.py",
    "scripts/vpn-conn-log",
    "scripts/validate_skill.py",
}


def classify_fixture(document: dict[str, Any]) -> str:
    kind = document["kind"]
    obs = document["observations"]
    if kind == "preflight" and obs.get("port_in_use"):
        return "port_conflict"
    if kind == "client":
        if len(obs.get("active_tuns", [])) > 1:
            return "multiple_tun"
        if obs.get("published_revision", 0) > obs.get("loaded_revision", 0):
            return "stale_subscription"
    if kind == "connection-logging":
        if (
            obs.get("hysteria2_family") == 6
            and 6 not in obs.get("logger_families", [])
            and obs.get("client_test_succeeded")
            and not obs.get("server_log_event_seen")
        ):
            return "ipv6_logging_blind_spot"
    if kind == "hysteria2":
        if obs.get("cloud_udp_rule") is False and not obs.get("request_seen"):
            return "udp_not_allowed"
        checksum_delta = obs.get("checksum_after", 0) - obs.get(
            "checksum_before", 0
        )
        if (
            obs.get("small_reply_received")
            and not obs.get("large_reply_received")
            and checksum_delta > 0
        ):
            return "large_packet_checksum_corruption"
        if (
            obs.get("family") == 4
            and obs.get("request_seen")
            and obs.get("reply_left")
            and not obs.get("reply_received")
            and checksum_delta == 0
        ):
            return "ipv4_udp_return_path_loss"
    return "unclassified"


def validate_frontmatter(errors: list[str]) -> None:
    text = (ROOT / "SKILL.md").read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        errors.append("SKILL.md: missing opening frontmatter delimiter")
        return
    try:
        frontmatter = text.split("---\n", 2)[1]
    except IndexError:
        errors.append("SKILL.md: missing closing frontmatter delimiter")
        return
    fields: dict[str, str] = {}
    for line in frontmatter.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            fields[key.strip()] = value.strip()
    if fields.get("name") != "self-hosted-vpn":
        errors.append("SKILL.md: frontmatter name must be self-hosted-vpn")
    description = fields.get("description", "")
    for term in ("OpenVPN", "Hysteria2", "Reality"):
        if term not in description:
            errors.append(f"SKILL.md: description must mention {term}")


def validate_markdown(errors: list[str]) -> None:
    for path in sorted(ROOT.rglob("*.md")):
        if ".git" in path.parts:
            continue
        relative = path.relative_to(ROOT)
        lines = path.read_text(encoding="utf-8").splitlines()
        if any(line.rstrip() != line for line in lines):
            errors.append(f"{relative}: trailing whitespace")
        if relative == Path("SKILL.md") and len(lines) > 200:
            errors.append(f"{relative}: {len(lines)} lines exceeds 200")
        if relative.parts[:1] == ("references",) and len(lines) > 250:
            errors.append(f"{relative}: {len(lines)} lines exceeds 250")

        previous_level = 0
        in_fence = False
        for number, line in enumerate(lines, 1):
            if line.startswith("```"):
                in_fence = not in_fence
                continue
            heading = re.match(r"^(#{1,6})\s+", line)
            if heading and not in_fence:
                level = len(heading.group(1))
                if previous_level and level > previous_level + 1:
                    errors.append(f"{relative}:{number}: skipped heading level")
                previous_level = level

        for match in MARKDOWN_LINK.finditer("\n".join(lines)):
            target = match.group(1).split("#", 1)[0].strip()
            if (
                not target
                or target.startswith(("http://", "https://", "mailto:", "#"))
            ):
                continue
            resolved = (path.parent / target).resolve()
            if not resolved.exists():
                errors.append(f"{relative}: broken relative link {target}")


def address_allowed(address: ipaddress._BaseAddress) -> bool:
    if address.version == 4 and any(address in network for network in DOC_V4):
        return True
    if address.version == 6 and address in DOC_V6:
        return True
    return (
        address.is_private
        or address.is_loopback
        or address.is_link_local
        or address.is_unspecified
        or address.is_multicast
    )


def validate_secrets(errors: list[str]) -> None:
    extensions = {".md", ".py", ".sh", ".json", ".txt", ""}
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or ".git" in path.parts or path.suffix not in extensions:
            continue
        relative = path.relative_to(ROOT)
        if relative == Path("scripts/validate_skill.py"):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if "-----BEGIN PRIVATE KEY-----" in text:
            errors.append(f"{relative}: private key material")
        for match in IPV4.finditer(text):
            try:
                address = ipaddress.ip_address(match.group())
            except ValueError:
                continue
            if not address_allowed(address):
                errors.append(f"{relative}: non-documentation public IPv4 address")
        for match in UUID.finditer(text):
            errors.append(f"{relative}: UUID-like value")
        for match in SECRET_ASSIGNMENT.finditer(text):
            value = match.group(2)
            if not (
                value.startswith("<")
                or "redacted" in value.lower()
                or value in {"none", "false", "true", "value"}
            ):
                errors.append(f"{relative}: possible assigned secret")
        for prohibited in (
            "root 账号的密码",
            "管理员账号的密码",
            "-o StrictHostKeyChecking=no",
        ):
            if prohibited in text:
                errors.append(f"{relative}: prohibited unsafe guidance: {prohibited}")


def validate_fixtures(errors: list[str]) -> None:
    found: set[str] = set()
    for path in sorted(FIXTURES.glob("*.json")):
        try:
            document = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{path.relative_to(ROOT)}: invalid JSON: {exc}")
            continue
        required = {
            "id",
            "kind",
            "contains_sensitive_data",
            "observations",
            "expected_classification",
        }
        missing = required - document.keys()
        if missing:
            errors.append(f"{path.relative_to(ROOT)}: missing {sorted(missing)}")
            continue
        found.add(document["id"])
        if document["contains_sensitive_data"] is not False:
            errors.append(f"{path.relative_to(ROOT)}: fixture must be redacted")
        actual = classify_fixture(document)
        if actual != document["expected_classification"]:
            errors.append(
                f"{path.relative_to(ROOT)}: expected "
                f"{document['expected_classification']}, got {actual}"
            )
    missing = REQUIRED_FIXTURES - found
    if missing:
        errors.append(f"tests/fixtures: missing required fixtures {sorted(missing)}")


def validate_modes(errors: list[str]) -> None:
    for name in EXECUTABLES:
        path = ROOT / name
        if not path.exists():
            errors.append(f"{name}: missing executable")
        elif not os.access(path, os.X_OK):
            errors.append(f"{name}: executable bit is not set")


def validate_release_metadata(errors: list[str]) -> None:
    required = ("CHANGELOG.md", "LICENSE", "RELEASING.md", "SUPPORT.md")
    for name in required:
        if not (ROOT / name).is_file():
            errors.append(f"{name}: required release file is missing")
    if (ROOT / "CHANGELOG.md").is_file():
        changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
        if "## [Unreleased]" not in changelog:
            errors.append("CHANGELOG.md: missing Unreleased section")
    if (ROOT / "SUPPORT.md").is_file():
        support = (ROOT / "SUPPORT.md").read_text(encoding="utf-8")
        if not re.search(r"Last verified: \d{4}-\d{2}-\d{2}\.", support):
            errors.append("SUPPORT.md: missing last-verified date")
    if (ROOT / "LICENSE").is_file():
        license_text = (ROOT / "LICENSE").read_text(encoding="utf-8")
        if not license_text.startswith("MIT License"):
            errors.append("LICENSE: expected MIT license text")


def main() -> int:
    errors: list[str] = []
    validate_frontmatter(errors)
    validate_markdown(errors)
    validate_secrets(errors)
    validate_fixtures(errors)
    validate_modes(errors)
    validate_release_metadata(errors)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print(f"validation failed with {len(errors)} error(s)", file=sys.stderr)
        return 1
    print("skill validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

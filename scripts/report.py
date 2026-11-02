#!/usr/bin/env python3
"""Emit a stable, redacted diagnostic report using only the standard library."""

from __future__ import annotations

import argparse
import datetime as dt
import ipaddress
import json
import re
import sys
from typing import Any


SENSITIVE_ASSIGNMENT = re.compile(
    r"(?i)\b(password|passwd|secret|token|uuid|private[_ -]?key|public[_ -]?key|short[_ -]?id|authorization|account|username|user)\s*[:=]\s*([^\s,;]+)"
)
URL = re.compile(r"https?://[^\s\"'<>]+", re.IGNORECASE)
UUID = re.compile(
    r"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\b"
)
IP_CANDIDATE = re.compile(
    r"(?<![A-Za-z0-9_.:])(?:\d{1,3}(?:\.\d{1,3}){3}|[0-9A-Fa-f:]{3,})(?![A-Za-z0-9_.:])"
)


def redact_ip(match: re.Match[str]) -> str:
    value = match.group(0)
    try:
        address = ipaddress.ip_address(value)
    except ValueError:
        return value
    if address.is_loopback or address.is_unspecified:
        return value
    if address.version == 4:
        octets = value.split(".")
        return ".".join(octets[:3] + ["x"])
    return "<redacted-ipv6>"


def redact_text(value: str) -> str:
    value = re.sub(
        r"-----BEGIN [^-]+-----.*?-----END [^-]+-----",
        "<redacted-key>",
        value,
        flags=re.DOTALL,
    )
    value = SENSITIVE_ASSIGNMENT.sub(lambda m: f"{m.group(1)}=<redacted>", value)
    value = URL.sub("<redacted-url>", value)
    value = UUID.sub("<redacted-uuid>", value)
    return IP_CANDIDATE.sub(redact_ip, value)


def redact(value: Any) -> Any:
    if isinstance(value, str):
        return redact_text(value)
    if isinstance(value, list):
        return [redact(item) for item in value]
    if isinstance(value, dict):
        return {key: redact(item) for key, item in value.items()}
    return value


def parse_check(value: str) -> dict[str, str]:
    parts = value.split("|", 2)
    if len(parts) != 3:
        raise argparse.ArgumentTypeError("check must be NAME|STATUS|DETAIL")
    name, status, detail = parts
    if status not in {"pass", "warning", "fail", "info", "unknown"}:
        raise argparse.ArgumentTypeError(f"invalid check status: {status}")
    return {"name": name, "status": status, "detail": detail}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tool", required=True)
    parser.add_argument("--status", choices=("pass", "warning", "fail"), required=True)
    parser.add_argument("--classification", default="unclassified")
    parser.add_argument("--check", action="append", default=[], type=parse_check)
    parser.add_argument("--metadata", default="{}", help="JSON object")
    args = parser.parse_args()

    try:
        metadata = json.loads(args.metadata)
    except json.JSONDecodeError as exc:
        parser.error(f"invalid metadata JSON: {exc}")
    if not isinstance(metadata, dict):
        parser.error("metadata must be a JSON object")

    report = {
        "schema_version": 1,
        "tool": args.tool,
        "timestamp": dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat(),
        "status": args.status,
        "classification": args.classification,
        "checks": args.check,
        "metadata": metadata,
    }
    report = redact(report)

    print(f"{args.tool}: {args.status} ({args.classification})", file=sys.stderr)
    for check in report["checks"]:
        print(
            f"  [{check['status']}] {check['name']}: {check['detail']}",
            file=sys.stderr,
        )
    json.dump(report, sys.stdout, ensure_ascii=False, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

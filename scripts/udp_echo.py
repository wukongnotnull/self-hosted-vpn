#!/usr/bin/env python3
"""Minimal UDP echo probe for isolating transport from VPN configuration."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import socket
import sys

from report import redact


def emit(mode: str, status: str, detail: dict[str, object]) -> None:
    result = redact(
        {
            "schema_version": 1,
            "tool": "udp-echo",
            "timestamp": dt.datetime.now(dt.timezone.utc)
            .replace(microsecond=0)
            .isoformat(),
            "mode": mode,
            "status": status,
            **detail,
        }
    )
    print(f"udp-echo {mode}: {status}", file=sys.stderr)
    json.dump(result, sys.stdout, ensure_ascii=False, sort_keys=True)
    sys.stdout.write("\n")


def family_for(value: str) -> socket.AddressFamily:
    return socket.AF_INET6 if ":" in value else socket.AF_INET


def run_server(args: argparse.Namespace) -> int:
    family = family_for(args.bind)
    with socket.socket(family, socket.SOCK_DGRAM) as sock:
        sock.settimeout(args.timeout)
        sock.bind((args.bind, args.port))
        count = 0
        try:
            while not args.once or count == 0:
                payload, peer = sock.recvfrom(args.max_bytes)
                sock.sendto(payload, peer)
                count += 1
        except TimeoutError:
            emit("server", "fail", {"classification": "timeout", "requests": count})
            return 20
    emit("server", "pass", {"classification": "echoed", "requests": count})
    return 0


def run_client(args: argparse.Namespace) -> int:
    family = family_for(args.host)
    payload = (b"vpn-echo:" + (b"x" * args.bytes))[: args.bytes]
    with socket.socket(family, socket.SOCK_DGRAM) as sock:
        sock.settimeout(args.timeout)
        started = dt.datetime.now(dt.timezone.utc)
        try:
            sock.sendto(payload, (args.host, args.port))
            reply, peer = sock.recvfrom(max(args.bytes, 64))
        except TimeoutError:
            emit(
                "client",
                "fail",
                {
                    "classification": "no_reply",
                    "target": f"{args.host}:{args.port}",
                    "bytes": len(payload),
                },
            )
            return 20
    elapsed = (dt.datetime.now(dt.timezone.utc) - started).total_seconds() * 1000
    status = "pass" if reply == payload else "fail"
    emit(
        "client",
        status,
        {
            "classification": "echo_matched" if status == "pass" else "payload_mismatch",
            "target": f"{peer[0]}:{peer[1]}",
            "bytes": len(reply),
            "round_trip_ms": round(elapsed, 2),
        },
    )
    return 0 if status == "pass" else 20


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser()
    sub = root.add_subparsers(dest="mode", required=True)

    server = sub.add_parser("server")
    server.add_argument("--bind", default="0.0.0.0")
    server.add_argument("--port", type=int, required=True)
    server.add_argument("--timeout", type=float, default=30)
    server.add_argument("--max-bytes", type=int, default=65535)
    server.add_argument("--once", action="store_true")
    server.set_defaults(handler=run_server)

    client = sub.add_parser("client")
    client.add_argument("--host", required=True)
    client.add_argument("--port", type=int, required=True)
    client.add_argument("--bytes", type=int, default=9)
    client.add_argument("--timeout", type=float, default=3)
    client.set_defaults(handler=run_client)
    return root


def main() -> int:
    args = parser().parse_args()
    if not 1 <= args.port <= 65535:
        raise SystemExit("port must be between 1 and 65535")
    if getattr(args, "bytes", 1) < 1:
        raise SystemExit("--bytes must be positive")
    return args.handler(args)


if __name__ == "__main__":
    raise SystemExit(main())

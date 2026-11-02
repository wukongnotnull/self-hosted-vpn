# Diagnostic tools

All diagnostic commands are read-only unless their name and help explicitly say they create a test artifact.

## Output contract

- Human summary: stderr.
- Machine report: one JSON object on stdout.
- Addresses, URLs, UUIDs, credentials and key-like fields are redacted automatically.
- Exit `0`: pass.
- Exit `10`: warning or incomplete evidence.
- Exit `20`: failed check.
- Exit `64`: invalid usage.
- Exit `69`: missing dependency.
- Exit `77`: insufficient permission.

## Commands

```bash
scripts/preflight.sh
scripts/diagnose-client-macos.sh
scripts/diagnose-hy2.sh --port <HY2_PORT>
scripts/diagnose-reality.sh --port <REALITY_PORT>
scripts/acceptance.sh --expected-exit <SERVER_IP>
```

Capture observations can be supplied to the protocol classifiers without granting packet-capture privileges:

```bash
scripts/diagnose-hy2.sh \
  --family 4 \
  --tiny-request yes \
  --reply-left yes \
  --reply-received no \
  --csum-before <COUNT_BEFORE> \
  --csum-after <COUNT_AFTER>

scripts/diagnose-reality.sh \
  --syn-seen yes \
  --synack-left yes \
  --ack-seen no
```

Run a minimal UDP echo independently of Xray:

```bash
python3 scripts/udp_echo.py server --bind <SERVER_ADDRESS> --port <TEST_PORT> --once
python3 scripts/udp_echo.py client --host <SERVER_ADDRESS> --port <TEST_PORT> --bytes 9
```

Create a fixed-size file only after checking the destination:

```bash
scripts/make-test-file.sh --output <NEW_PATH> --bytes <SIZE> --confirm
```

`scripts/vpn-conn-log` reads live conntrack events by default. It requires at least one protocol port and discovers local addresses with `ip -j address`. Client addresses are redacted unless `--raw-addresses` is explicitly selected:

```bash
sudo scripts/vpn-conn-log \
  --reality-port <REALITY_PORT> \
  --hy2-port <HY2_PORT>
```

Do not include raw JSON reports in issues until their redaction has been reviewed.

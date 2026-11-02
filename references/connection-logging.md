# Connection logging

Use transport connection events, not Xray access logs, to investigate client Error or Timeout.

## Why

Xray access logs describe traffic after proxy authentication. A TCP handshake or UDP exchange that never becomes a proxy session may produce no Xray access entry.

Keep:

- `/var/log/x-ui/error.log` for Xray warning/error output;
- `/var/log/x-ui/conn.log` for client-to-server TCP/UDP connection state.

Do not enable verbose access logging merely to diagnose failed handshakes.

## Error log

Configure the panel's persistent Xray template, not only the generated runtime file:

```json
"log": {
  "access": "none",
  "dnsLog": false,
  "error": "error.log",
  "loglevel": "warning",
  "maskAddress": ""
}
```

Restart x-ui and verify the running config.

## Connection events

Install `conntrack` and enable accounting:

```text
net.netfilter.nf_conntrack_acct=1
```

The logger must:

- consume NEW, UPDATE and DESTROY events;
- support IPv4 and IPv6;
- recognize every local server address;
- retain only original-direction traffic to `<REALITY_PORT>` or `<HY2_PORT>`;
- ignore server-originated connections to Reality camouflage destinations;
- write timestamps, protocol, destination port, redacted client address, client port and state.

Result mapping:

- `event=up`: bidirectional UDP or established TCP.
- `result=handshake_timeout`: TCP never reached ESTABLISHED.
- `result=no_reply`: UDP never became bidirectional.
- `result=closed`: established/bidirectional flow ended.

For UDP, host-level checksum deltas may be attached, but they are not proof that one specific flow owned every new error.

## Service and rotation

The repository's `scripts/vpn-conn-log` is the source artifact. Install a reviewed copy under `/usr/local/sbin/`, run it as a dedicated systemd service with automatic restart, and rotate with `copytruncate`.

The default report redacts client addresses. Keeping raw client IPs requires explicit user choice and a retention period.

## Interpretation limits

- The client's literal Error string is not sent to the server.
- Multiple clients behind one public address may be distinguishable only by source port.
- A long-lived UDP session does not create a new line for every delay test.
- If Hysteria2 moves to IPv6 but the logger reads only IPv4 events, an empty log does not mean the request missed the server.
- If the user's reported second has no event in a correctly configured dual-stack logger, the attempt likely did not reach the server.

# 3x-ui deployment and clients

Use this path only after the user selects subscription-based routing.

## Variables

Choose values from the current environment; do not reuse a case study:

- `<PANEL_PORT>`
- `<SUBSCRIPTION_PORT>`
- `<REALITY_PORT>`
- `<HY2_PORT>`
- `<SERVER_IPV4>`
- `<SERVER_IPV6>` when available
- `<HY2_SNI>`
- `<REALITY_DESTINATION>`

## Security

- Install from the current [3x-ui project releases](https://github.com/MHSanaei/3x-ui/releases) after checking the release notes and checksum/signature information that is available.
- Use SSH keys and a non-root sudo account.
- Keep the panel on loopback with an SSH tunnel where supported. Otherwise restrict `<PANEL_PORT>` to administrator source addresses.
- Do not expose a plaintext HTTP panel to all IPv4 or IPv6 sources.
- Keep subscription tokens, UUIDs, Reality keys and Hysteria2 passwords out of chat, repositories and shell history.
- Back up the panel database and exported inbound configuration before upgrades.

## Preflight

Run `scripts/preflight.sh` and stop if:

- a selected port is occupied;
- cloud and system firewall state cannot be established;
- no recovery console or independent SSH path exists;
- an existing TLS service conflicts with the Reality port;
- the server platform is outside the tested matrix.

## Node layout

Use two inbounds for each user:

| Role | Protocol | Transport |
| --- | --- | --- |
| Daily | Hysteria2 | UDP on `<HY2_PORT>` |
| Fallback | VLESS + Reality | TCP on `<REALITY_PORT>` |

Reality flow is `xtls-rprx-vision`. Its destination must be reachable and must not conflict with another local TLS service.

Hysteria2 uses a dedicated UDP port. A self-signed certificate may require `skip-cert-verify: true` for that node. Explain the risk and do not disable certificate verification globally.

## Firewall

Allow only required traffic:

- panel TCP from administrator sources;
- subscription TCP from intended clients;
- Reality TCP on `<REALITY_PORT>`;
- Hysteria2 UDP on `<HY2_PORT>`.

Create separate IPv4 and IPv6 rules when both families are used. TCP permission on a port does not permit UDP on the same number.

## Client routing

The rules are ordered:

```yaml
- GEOIP,CN,DIRECT
- GEOSITE,CN,DIRECT
- MATCH,PROXY
```

Use rule mode. In Shadowrocket, global routing must be **Config**. `FINAL` or `MATCH` stays last.

The subscription should include both nodes and the routing rules. Do not distribute a single-node QR code as the user's complete configuration.

## Client matrix

- Desktop: Clash Verge Rev with a supported mihomo core.
- Android: Clash Meta for Android or another verified mihomo client.
- iOS: Shadowrocket; Hysteria2 self-signed certificates require node-scoped **Allow Insecure**.

Client-specific overrides that a refresh would erase belong in an enhancement script. After changing the script, refresh the profile and reload the running core.

## Acceptance

Run `scripts/acceptance.sh` and verify:

1. Rule mode is active.
2. `AUTO` prefers Hysteria2 when healthy and falls back to Reality.
3. The exit is the VPS.
4. A mainland target is direct.
5. Fixed-size transfer completes.
6. Profile refresh and client restart preserve required overrides.

See [hy2-diagnostics.md](hy2-diagnostics.md) or [reality-diagnostics.md](reality-diagnostics.md) for protocol-specific failures.

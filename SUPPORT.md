# Support matrix

Last verified: 2026-11-02.

Runtime capability detection takes priority over version strings. A matching version does not override a failed preflight.

## Fully verified path

| Layer | Verified baseline | Verified behavior |
| --- | --- | --- |
| Server | Ubuntu 24.04, Linux 6.8, amd64 | systemd, `ip`, `ss`, conntrack, IPv4 and global IPv6 |
| Panel | 3x-ui 3.8.5 | panel-managed inbounds, persistent Xray template, database backup |
| Proxy core | Xray 26.9.9 | Hysteria2, VLESS + Reality, `finalmask.quicParams.disablePathMTUDiscovery` |
| Agent host | Cursor 3.27.22 on macOS 27.2, arm64 | SSH-key administration, local diagnostics and profile reload |
| Desktop client | Clash Verge Rev 2.5.8 | subscription, enhancement script, rule mode, TUN |
| Client core | mihomo 1.19.32 | Hysteria2, VLESS Reality, Unix controller, fixed client upload value |
| Network layout | Reality on IPv4/TCP; Hysteria2 on IPv6/UDP | fallback selection, fixed-size transfer and subscription refresh |

The verified cloud provider was Tencent Cloud Lighthouse. Provider-specific console automation is not part of the portable skill contract.

## Limited support

| Path | Status | Required handling |
| --- | --- | --- |
| OpenVPN Access Server + OpenVPN Connect | Workflow and split-route pattern previously exercised; exact legacy versions were not captured | Confirm the current official support matrix and complete the fresh-VM checklist before production |
| Android mihomo clients | Configuration shape only | Probe Hysteria2, Reality, rule mode and certificate controls before change |
| Shadowrocket | Configuration shape only | Probe node-scoped insecure TLS and rule order; do not assume menu names |
| Other Ubuntu kernels or 3x-ui/Xray versions | Unknown until probed | Check required commands and JSON fields in the running config |

## Unsupported by default

- Linux distributions other than Ubuntu 24.04.
- Servers without systemd or an independent recovery console.
- Windows or Linux Agent hosts.
- Generic Clash forks, proprietary clients other than those listed above, and WireGuard.
- Environments where the cloud firewall, system firewall or active configuration source cannot be identified.
- Automatic changes when the user cannot restore SSH or panel access.

For an unknown environment, run `scripts/preflight.sh`, inspect the required feature, and stop if it cannot be confirmed. Do not infer support from a similar product name.

## Required feature probes

Before any mutation, confirm:

- the selected port is free and the intended TCP or UDP listener can be inspected;
- cloud and system firewall rules are independently visible;
- the panel has a restorable database or export;
- the running Xray configuration contains each field the change depends on;
- the client core supports the selected protocol and enhancement syntax;
- a physical route remains available while TUN is enabled;
- global IPv6 exists at both ends before choosing IPv6 fallback;
- the connection logger sees the same address family as the node.

## Fresh-VM acceptance

Use synthetic credentials and documentation addresses only.

1. Provision the verified server image with an SSH key, non-root sudo user and recovery console.
2. Run `scripts/preflight.sh`; archive the redacted JSON.
3. Install the recorded panel/core baseline from an official release and record checksums where available.
4. Configure new parameter values; never import a case-study credential or address.
5. Validate Reality and Hysteria2 independently, then validate fallback.
6. Run a fixed-size download and a 30MB-or-larger upload.
7. Refresh the subscription, restart the client core, restart x-ui and reboot the VM.
8. Confirm the panel, inbounds, firewall rules and client overrides persist.
9. Exercise database/config restore and one client rollback.
10. Run the negative cases below.

## Negative cases

- Occupied TCP/UDP port stops preflight.
- Missing cloud UDP rule classifies as UDP not allowed.
- Stale subscription revision is detected before protocol changes.
- Multiple TUN owners produce a warning.
- Large-packet checksum growth is not classified as return-path loss.
- Tiny IPv4 reply loss with flat checksum counters is classified as return-path loss.
- IPv6 Hysteria2 with an IPv4-only logger is classified as a logging blind spot.

The synthetic evidence for these cases is in [tests/fixtures](tests/fixtures/README.md).

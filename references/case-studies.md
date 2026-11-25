# Case studies

These are observations from specific paths. They are evidence that a diagnostic method worked, not defaults for another deployment.

## Lossy long-RTT path

Observed on one mainland-to-overseas path:

- RTT was roughly 160–200 ms with substantial loss.
- TCP cubic collapsed to tens of KB/s.
- BBR improved Reality but one stream still remained much slower than aggregate parallel traffic.
- Hysteria2 was the practical daily path; Reality remained the fallback.

Lesson: delay measures a short request, not useful video or download throughput.

## Hysteria2 upload pacing

On one deployment:

- leaving client `up` empty made long uploads progressively slower;
- `50 Mbps` held a 30MB upload near the best stable rate;
- higher values produced short spikes but did not improve the long transfer.

Lesson: select client send rate from repeated long transfers. Do not copy `50 Mbps`.

## IPv4 large-packet corruption

On one path:

- UDP payloads around 1441 bytes arrived with checksum errors;
- packets below roughly 600 bytes did not;
- the client-side copy was valid;
- a path device fragmented around the observed IP size and reassembly mixed packet tails.

The deployment used an IPv4 input cap above the QUIC initial packet and below the corruption threshold, plus disabled server QUIC path MTU discovery. The exact cap was path-specific.

Lesson: measure the boundary. Capping below the initial packet breaks the handshake, and dropping server egress packets breaks replies.

## IPv4 UDP return path loss

On one VPS route:

- IPv4 UDP requests reached the server;
- server replies left;
- even tiny replies did not reach the home client;
- checksum errors stayed at zero;
- another overseas UDP service still returned packets.

Changing UDP ports did not repair the route. The VPS and home both supported global IPv6, so Hysteria2 alone was moved to IPv6 while Reality remained on IPv4/TCP.

Validation showed:

- repeated Hysteria2 delay success;
- bidirectional IPv6 UDP capture;
- fixed-size transfer around the configured rate;
- no new UDP checksum errors.

Lesson: distinguish a broken server-specific return path from a household-wide UDP block and from large-packet corruption.

## Reality port-specific return loss

On one path, SYN reached a dedicated TCP port and SYN-ACK left, but the client never ACKed. Other ports completed the handshake. Reality was moved only after a temporary listener proved the candidate port worked and was not occupied by another TLS service.

Lesson: do not rotate Reality keys for a TCP handshake that never completes.

## IPv6 exit geolocated to another region

On one dual-stack VPS:

- an AI coding assistant returned HTTP 403 with reason `UNSUPPORTED_LOCATION`;
- the account region and the IPv4 exit were both in the supported country;
- an IPv4-only hostname of the provider answered normally, while its IPv6-only and dual-stack hostnames redirected to a regional site;
- the client ran mihomo in fake-ip mode, so the server resolved names and connected over IPv6;
- the `direct` outbound had no domain strategy.

Setting the outbound to prefer IPv4 in the panel template fixed the dual-stack hostname, and lookups reported the IPv4 exit. The first attempt used the outbound-level setting, which the installed Xray reported as deprecated; it was moved under `sockopt`.

Two process mistakes were recorded. The SSH session ran through the node and was closed by the restart. A wildcard path inside a root-only directory was expanded by the unprivileged shell, matched nothing, and stopped the command chain before the restart.

Lesson: an IP lookup showing the right country proves one address family only. Test the provider's own hostnames per family before touching the account or the node. See [exit-geo-diagnostics.md](exit-geo-diagnostics.md).

## Values intentionally omitted

Production IPs, IPv6 addresses, subscription paths, UUIDs, passwords, keys and administrator paths are excluded. Keep new case studies similarly redacted.

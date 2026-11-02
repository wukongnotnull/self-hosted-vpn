# VLESS + Reality diagnostics

Reality is the fallback path. A green short-request delay does not prove useful throughput.

## Classify the failure

1. Confirm the server listens on TCP `<REALITY_PORT>`.
2. Confirm no other TLS service owns the port.
3. Capture the TCP handshake on the server.
4. Test from the client's physical interface, not through an active Clash TUN.
5. Only inspect Reality keys after TCP reachability is proven.

| Capture | Meaning |
| --- | --- |
| No SYN reaches server | wrong route/address, cloud firewall, or client interception |
| SYN arrives; no SYN-ACK leaves | listener or system firewall |
| SYN-ACK leaves; client retransmits SYN and sends no ACK | return path or port-specific filtering |
| TCP establishes; Xray does not accept the session | Reality authentication or protocol parameters |
| Delay works; fixed-size transfer is poor | loss/RTT/congestion, not authentication |

An `nc` success while the destination route uses `utun` only proves Clash accepted the local connection. Bind the physical source address and verify the server sees the home public address.

## Port changes

Before moving Reality:

- start a temporary listener on the candidate port;
- test the full handshake from the physical interface;
- verify no existing Web/TLS service uses it;
- keep the subscription port separate.

Update the panel-managed inbound, restart x-ui, verify the running config, and refresh client subscriptions. Do not edit only the runtime JSON.

## Authentication

Verify as one set:

- client UUID;
- Reality public key;
- short ID;
- SNI/server name;
- flow `xtls-rprx-vision`;
- hybrid key capability when required by the detected Xray/client versions.

Do not rotate keys to diagnose a TCP handshake that never completed.

## Throughput

Record:

- RTT;
- packet loss;
- active congestion control;
- fixed-size single-stream download;
- parallel aggregate download.

BBR may improve a lossy long-RTT TCP path, but it cannot remove handshake round trips or make one TCP stream equivalent to Hysteria2. Apply congestion-control changes only with before/after measurements and a rollback file.

## Acceptance

- TCP handshake completes from the physical path.
- Reality delay succeeds after a fresh subscription load.
- `AUTO` can fall back to Reality when Hysteria2 is unavailable.
- Fixed-size transfer meets the documented minimum for the deployment.
- Existing TLS and subscription services still work.

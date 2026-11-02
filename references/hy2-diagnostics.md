# Hysteria2 diagnostics

Do not treat every Error or Timeout as the same fault.

## Decision tree

1. Confirm Reality still works and the server is reachable.
2. Capture the client physical interface and server interface at the same time.
3. Record `UdpInCsumErrors` before and after a controlled test.
4. Test a tiny UDP echo independently of Xray.
5. Classify before changing configuration.

| Evidence | Classification |
| --- | --- |
| No UDP reaches the server | cloud firewall, system firewall, wrong address/port, or TUN routing |
| Tiny request reaches server, no reply leaves | listener or local firewall |
| Reply leaves server, tiny reply never reaches client, checksum errors stay flat | one-way UDP return path |
| Tiny packets work; checksum errors rise only with large packets | fragmentation/reassembly corruption |
| Delay works; download is fast; long upload collapses | missing or unsuitable client `up` |
| Delay works; fixed-size transfer is slow | congestion/rate/path issue, not connectivity |

Use `scripts/diagnose-hy2.sh` to produce the evidence bundle.

## Server rate and buffers

Only tune after measurement. Parameterize:

- `<HY2_UP_Mbps>`
- `<HY2_DOWN_Mbps>`
- `<CLIENT_UP_Mbps>`

Set the Hysteria2 inbound's `up` and `down` to measured values and enable `ignoreClientBandwidth` only when the chosen Xray version supports them. Restart x-ui, then verify the running configuration contains all three values.

UDP buffer tuning must be justified by drop evidence. Record old sysctls and restore them if acceptance does not improve.

## Slow upload

The server's `ignoreClientBandwidth` does not set the client's send rate. Persist a client value in the enhancement script:

```javascript
function main(config, profileName) {
  for (const proxy of config.proxies || []) {
    if (proxy && proxy.type === "hysteria2") {
      proxy.up = "<CLIENT_UP_Mbps> Mbps";
    }
  }
  return config;
}
```

Reload the running core. Measure both 10MB and at least 30MB; keep the highest value whose long transfer remains stable. Do not choose from one short spike.

## Large-packet corruption

This classification requires all of:

- small packets travel in both directions;
- corruption is concentrated above an observed packet size;
- `UdpInCsumErrors` rises during the test;
- the client-side copy was valid before entering the path.

Choose `<MEASURED_MTU_CAP>` above the QUIC initial packet and below the observed corruption threshold. Apply the inbound IPv4 cap with a reversible, persistent firewall rule.

For server egress, use the Xray capability that disables QUIC path MTU discovery:

```json
"finalmask": {
  "quicParams": {
    "disablePathMTUDiscovery": true
  }
}
```

Restart x-ui only after the client uses Reality or another independent SSH route. Verify the running config still contains `finalmask`.

Do not:

- cap below the QUIC initial packet;
- drop oversized server egress packets;
- rely on mihomo `udp-mtu` to limit QUIC itself;
- modify the client NIC MTU as the primary fix;
- copy an observed threshold from another path.

## Complete IPv4 UDP return loss

If even tiny IPv4 UDP replies leave the server but never reach the client, changing Hysteria2 credentials, rates, ports or MTU does not repair the route.

Before using IPv6:

1. Confirm both ends have global IPv6 and default routes.
2. Confirm the provider can enable IPv6 without changing the existing IPv4.
3. Switch the client to Reality before a provider-initiated reboot.
4. Add a cloud firewall rule for IPv6 UDP `<HY2_PORT>`.
5. Prove a tiny IPv6 UDP echo works both ways.

Then override only Hysteria2:

```javascript
if (proxy && proxy.type === "hysteria2") {
  proxy.server = "<SERVER_IPV6>";
}
```

YAML stores the bare IPv6 value without brackets. Reload the core and capture:

```bash
tcpdump -ni <SERVER_IFACE> 'ip6 and udp port <HY2_PORT>'
```

Reality may remain on the validated IPv4/TCP path. If the subscription still publishes IPv4, the enhancement applies only to clients that load it; update other clients separately.

Do not copy an IPv4 length-drop rule into `ip6tables` merely because an IPv6 UDP payload is large. IPv6 routers do not perform intermediate fragmentation.

## Acceptance

- Hysteria2 delay succeeds repeatedly.
- `AUTO` selects it.
- The capture shows the intended address family and port.
- Fixed-size download and upload complete.
- `UdpInCsumErrors` and socket drop counters do not rise.
- Refreshing the subscription does not remove required overrides.

Observed numbers and rejected experiments belong in [case-studies.md](case-studies.md), not in operational defaults.

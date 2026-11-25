# Exit location diagnostics

Use this when a service rejects the user by location although the node is selected and an IP lookup shows the expected country. Typical signals are `UNSUPPORTED_LOCATION`, "not available in your location", or a redirect to a regional site.

The usual cause on a dual-stack server is that the two address families are geolocated differently. Xray's `freedom` outbound resolves a dual-stack name on the server and may connect over IPv6, so the service sees the IPv6 address while IPv4-only lookups look correct.

## Classify the failure

Run every check from the client through the selected node. All checks are read-only.

1. Record the IPv4 exit and the IPv6 exit separately, using one lookup that is IPv4-only and one that prefers IPv6.
2. Compare what the affected provider returns for an IPv4-only hostname, an IPv6-only hostname and a dual-stack hostname. For Google:

   ```bash
   for host in ipv4.google.com ipv6.google.com www.google.com; do
     curl -s -m 10 -o /dev/null \
       -w "$host %{http_code} -> %{redirect_url}\n" "https://$host/"
   done
   ```

3. Check the account's own region setting with the provider.
4. Check whether the client resolves names itself. With mihomo fake-ip or any mode that sends the hostname to the node, the server chooses the address family.

| Evidence | Meaning |
| --- | --- |
| IPv4-only passes; IPv6-only and dual-stack fail | the IPv6 exit is geolocated to an unsupported region |
| IPv4-only and IPv6-only both fail | the provider rejects the server's addresses; changing the family will not help |
| All pass, the application still fails | account region, cached session, or the application is not using the node |
| The exit is not the server | mode, node selection or TUN; see the client checks in [3xui.md](3xui.md) |

Third-party IP databases disagree with each other and with the provider. Trust the provider's own response, not a lookup site.

## What does not fix it

- Disabling IPv6 in the client while the hostname is still resolved on the server.
- Rotating UUIDs, Reality keys or ports.
- Editing only the generated runtime JSON; the panel rewrites it on restart.

## Fix: prefer IPv4 on the direct outbound

Scope the change to outbound connections so IPv6 inbounds, including a Hysteria2 node moved to IPv6, keep working.

Probe the running Xray version first. Newer releases deprecate `freedom.settings.domainStrategy` and log a warning; the value belongs under `streamSettings.sockopt`:

```json
{
  "tag": "direct",
  "protocol": "freedom",
  "streamSettings": { "sockopt": { "domainStrategy": "UseIPv4" } }
}
```

Keep the outbound's existing `settings`. Use the older `settings.domainStrategy` location only when the detected version does not support the `sockopt` form.

`UseIPv4` still falls back to IPv6 for names that have no IPv4 address. That is expected. Use `ForceIPv4` only when the user accepts that IPv6-only destinations will fail.

Apply it as one reversible change:

1. Confirm the change, the restart and the short interruption with the user.
2. Make sure the SSH session does not pass through the node. A session routed through it is closed by the restart; schedule the restart on the server or use the physical path.
3. Back up the panel database with SQLite's online backup, not a plain copy of a database that has a live write-ahead log. Restrict the backup to its owner.
4. Write the outbound into the panel-managed Xray template through the panel or the database.
5. Restart x-ui and read the generated running configuration.
6. Check the service log for deprecation warnings and errors from this restart.

Paths under a root-only directory are not visible to an unprivileged shell. Pass exact paths to `sudo`; a wildcard is expanded before `sudo` runs and matches nothing.

Disabling IPv6 for the whole server is a broader alternative. It breaks every IPv6 inbound and is not the default.

## Acceptance

- The dual-stack hostname returns the same result as the IPv4-only hostname.
- A lookup that prefers IPv6 now reports the IPv4 exit.
- The running configuration contains the strategy after an x-ui restart.
- No deprecation warning or error was logged by the last restart.
- Both nodes still connect, including any IPv6 inbound.
- The user retries the affected application. Sign out and back in if it cached the earlier rejection. Report this item as unverified until the user confirms it.

## Rollback

Remove the strategy from the `direct` outbound in the panel template and restart x-ui, or restore the database backup as described in [rollback.md](rollback.md).

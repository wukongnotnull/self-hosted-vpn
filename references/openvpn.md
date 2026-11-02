# OpenVPN Access Server

Use this path only after the user selects OpenVPN Access Server.

## Preconditions

- Supported server OS and architecture are confirmed against the current [official installation guide](https://openvpn.net/as-docs/installation.html).
- SSH key access and a separate recovery path work.
- The admin port, client portal port, UDP VPN port and TCP fallback port are recorded as variables:
  - `<AS_ADMIN_PORT>`
  - `<AS_PORTAL_PORT>`
  - `<VPN_UDP_PORT>`
  - `<VPN_TCP_PORT>`
- Existing listeners and cloud firewall rules have been inventoried.

Do not paste an installation command from memory. Fetch the current command from the official guide for the detected OS.

## Security

- Use a non-root administrator and rotate bootstrap credentials after first login.
- Restrict the admin interface to an SSH tunnel or administrator source addresses.
- Keep the user portal separate from the admin interface.
- Prefer UDP for the tunnel; keep TCP only as a fallback for networks that block UDP.
- Back up Access Server configuration before upgrades or routing changes.

## Split routing

Keep full-tunnel Internet routing enabled. Add mainland routes only in:

**Configuration → Advanced VPN → Server Config Directives**

```text
block-ipv6
# <SITE> <DATE> <WHY_THIS_PREFIX_IS_MAINLAND>
push "route <NETWORK> <NETMASK> net_gateway"
```

Save and select **Update Running Server**. The client must disconnect and reconnect before new pushes apply.

Do not put split routes in downloaded `.ovpn` files or Client Config Directives. OpenVPN Connect may discard those lines, and profile refreshes overwrite local edits.

## Choosing prefixes

1. Resolve the target from the VPN exit.
2. Add only confirmed mainland addresses.
3. Keep Hong Kong, Singapore and other overseas CDN addresses in the tunnel.
4. Record the site, date and reason above every prefix.
5. Never copy another deployment's prefix list.

## DNS

Keep the server's existing resolver unless evidence shows it is wrong. Do not make a mainland public DNS server the client's default merely to speed up domestic sites.

Optional host routes to a DNS service mean only that those IPs may be reached directly; they do not change the selected resolver.

## Validation

1. Disable other VPN and Clash TUN sessions.
2. Connect with OpenVPN Connect.
3. Confirm `https://ip.sb` shows the VPS for general Internet traffic.
4. Resolve a known mainland test host and check its route uses the physical gateway.
5. Confirm an overseas target still uses the VPN.
6. Reboot or restart Access Server and repeat the checks.

Do not use ping to the VPS as the only signal; providers commonly block it.

## Rollback

Before changing Server Config Directives, save the previous text. Roll back by restoring it, selecting **Update Running Server**, and reconnecting the client.

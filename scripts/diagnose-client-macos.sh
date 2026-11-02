#!/usr/bin/env bash

set -u
# shellcheck source=scripts/lib.sh
. "$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/lib.sh"

if [ "${1:-}" = "--help" ]; then
  cat <<'EOF'
Usage: diagnose-client-macos.sh

Read-only macOS checks for default routing, duplicate TUN interfaces, system
proxy state and an optional VPN_SERVER route. JSON goes to stdout.
EOF
  exit 0
fi
if [ "$#" -ne 0 ]; then
  usage_error "diagnose-client-macos.sh takes no arguments"
  exit $?
fi

if ! require_cmd python3; then
  printf '{"tool":"diagnose-client-macos","status":"fail","classification":"missing_python3"}\n'
  exit "$VPN_EXIT_DEPENDENCY"
fi

if [ "$(uname -s 2>/dev/null)" != Darwin ]; then
  add_check platform fail "this diagnostic supports macOS only"
  finish_report diagnose-client-macos fail unsupported_platform
  exit $?
fi
add_check platform pass "$(sw_vers -productVersion 2>/dev/null || uname -r)"

status=pass
classification=healthy

default_route=$(route -n get default 2>/dev/null | awk '/gateway:|interface:/{printf "%s=%s;",$1,$2}')
if [ -n "$default_route" ]; then
  add_check default-route pass "$default_route"
else
  add_check default-route fail "no IPv4 default route"
  status=fail
  classification=no_default_route
fi

tun_count=$(ifconfig -l 2>/dev/null | tr ' ' '\n' | awk '/^utun[0-9]+$/{n++} END{print n+0}')
if [ "$tun_count" -gt 1 ]; then
  add_check tun warning "${tun_count} utun interfaces are present; verify only one VPN owns the route"
  [ "$status" = pass ] && status=warning
  classification=multiple_tun
elif [ "$tun_count" -eq 1 ]; then
  add_check tun pass "one utun interface is present"
else
  add_check tun info "no utun interface is present"
fi

proxy_summary=$(scutil --proxy 2>/dev/null | awk '/HTTPEnable|HTTPSEnable|SOCKSEnable/{gsub(/[ :]/,""); printf "%s;",$0}')
if printf '%s' "$proxy_summary" | grep -Eq 'Enable1'; then
  add_check system-proxy pass "$proxy_summary"
else
  add_check system-proxy info "system HTTP/HTTPS/SOCKS proxy is not enabled"
fi

if [ -n "${VPN_SERVER:-}" ]; then
  server_route=$(route -n get "$VPN_SERVER" 2>/dev/null | awk '/gateway:|interface:/{printf "%s=%s;",$1,$2}')
  if [ -n "$server_route" ]; then
    add_check vpn-server-route pass "${VPN_SERVER}: ${server_route}"
    case "$server_route" in
      *interface:utun*|*interface=utun*)
        add_check vpn-server-loop warning "server route uses utun; direct reachability is not proven"
        [ "$status" = pass ] && status=warning
        classification=server_routed_through_tun
        ;;
    esac
  else
    add_check vpn-server-route fail "cannot resolve or route VPN_SERVER"
    status=fail
    classification=server_unroutable
  fi
else
  add_check vpn-server-route info "set VPN_SERVER to inspect its route"
fi

global_v6=$(ifconfig 2>/dev/null | awk '/inet6 / && $2 !~ /^(fe80|::1)/ {print $2; exit}')
if [ -n "$global_v6" ]; then
  add_check ipv6 pass "global IPv6 address: ${global_v6}"
else
  add_check ipv6 info "no global IPv6 address detected"
fi

finish_report diagnose-client-macos "$status" "$classification"
exit $?

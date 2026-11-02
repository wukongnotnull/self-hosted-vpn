#!/usr/bin/env bash

set -u
# shellcheck source=scripts/lib.sh
. "$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/lib.sh"

if [ "${1:-}" = "--help" ]; then
  cat <<'EOF'
Usage: preflight.sh

Read-only environment inventory. Optional variables:
  PANEL_PORT SUBSCRIPTION_PORT REALITY_PORT HY2_PORT
  VPN_RECOVERY_CONFIRMED=yes

Human summary is written to stderr; redacted JSON is written to stdout.
Exit codes: 0 pass, 10 warning, 20 fail, 64 usage.
EOF
  exit 0
fi
if [ "$#" -ne 0 ]; then
  usage_error "preflight.sh takes no arguments"
  exit $?
fi

status=pass
classification=ready
os_name=$(uname -s 2>/dev/null || printf unknown)
os_release=$(uname -r 2>/dev/null || printf unknown)
arch=$(uname -m 2>/dev/null || printf unknown)

if ! require_cmd python3; then
  printf '{"tool":"preflight","status":"fail","classification":"missing_python3"}\n'
  exit "$VPN_EXIT_DEPENDENCY"
fi

case "$os_name" in
  Linux|Darwin)
    add_check platform pass "${os_name} ${os_release} ${arch}"
    ;;
  *)
    add_check platform warning "unverified platform: ${os_name} ${os_release} ${arch}"
    status=warning
    classification=unverified_platform
    ;;
esac

if [ "$(id -u)" -eq 0 ]; then
  add_check privilege warning "running as root; prefer a non-root sudo account"
  [ "$status" = pass ] && status=warning
elif has_cmd sudo; then
  if sudo -n true >/dev/null 2>&1; then
    add_check privilege pass "non-root account has non-interactive sudo"
  else
    add_check privilege info "non-root account; sudo may require interactive approval"
  fi
else
  add_check privilege warning "non-root account without sudo detected"
  [ "$status" = pass ] && status=warning
fi

if [ "${VPN_RECOVERY_CONFIRMED:-no}" = yes ]; then
  add_check recovery pass "independent recovery path confirmed by operator"
else
  add_check recovery warning "set VPN_RECOVERY_CONFIRMED=yes only after console or independent SSH is tested"
  status=warning
  classification=recovery_unconfirmed
fi

if [ "$os_name" = Linux ] && has_cmd ip; then
  default4=$(ip -4 route show default 2>/dev/null | tr '\n' ';')
  default6=$(ip -6 route show default 2>/dev/null | tr '\n' ';')
elif [ "$os_name" = Darwin ] && has_cmd route; then
  default4=$(route -n get default 2>/dev/null | awk '/interface:|gateway:/{printf "%s=%s;",$1,$2}')
  default6=$(route -n get -inet6 default 2>/dev/null | awk '/interface:|gateway:/{printf "%s=%s;",$1,$2}')
else
  default4=""
  default6=""
fi

if [ -n "$default4" ]; then
  add_check ipv4-default pass "$default4"
else
  add_check ipv4-default warning "no IPv4 default route detected"
  status=warning
fi
if [ -n "$default6" ]; then
  add_check ipv6-default pass "$default6"
else
  add_check ipv6-default info "no IPv6 default route detected"
fi

port_in_use() {
  protocol=$1
  port=$2
  if has_cmd ss; then
    ss -H -ln "$protocol" 2>/dev/null | awk '{print $5}' | grep -Eq "(^|:)$port$"
  elif has_cmd lsof; then
    if [ "$protocol" = udp ]; then
      lsof -nP -iUDP:"$port" 2>/dev/null | grep -q .
    else
      lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | grep -q .
    fi
  else
    return 2
  fi
}

check_port() {
  name=$1
  protocol=$2
  value=$3
  [ -z "$value" ] && return 0
  case "$value" in
    *[!0-9]*)
      add_check "port:${name}" fail "invalid port value"
      status=fail
      classification=invalid_port
      return 0
      ;;
  esac
  if port_in_use "$protocol" "$value"; then
    add_check "port:${name}" fail "${protocol}/${value} is already in use"
    status=fail
    classification=port_conflict
  else
    result=$?
    if [ "$result" -eq 2 ]; then
      add_check "port:${name}" warning "cannot inspect listeners; install ss or lsof"
      [ "$status" = pass ] && status=warning
    else
      add_check "port:${name}" pass "${protocol}/${value} is available"
    fi
  fi
}

check_port panel tcp "${PANEL_PORT:-}"
check_port subscription tcp "${SUBSCRIPTION_PORT:-}"
check_port reality tcp "${REALITY_PORT:-}"
check_port hysteria2 udp "${HY2_PORT:-}"

metadata=$(printf '{"os":"%s","release":"%s","architecture":"%s"}' "$os_name" "$os_release" "$arch")
finish_report preflight "$status" "$classification" "$metadata"
exit $?

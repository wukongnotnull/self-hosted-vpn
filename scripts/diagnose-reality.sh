#!/usr/bin/env bash

set -u
# shellcheck source=scripts/lib.sh
. "$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/lib.sh"

usage() {
  cat <<'EOF'
Usage: diagnose-reality.sh [options]
  --port PORT
  --syn-seen yes|no|unknown
  --synack-left yes|no|unknown
  --ack-seen yes|no|unknown
  --xray-accepted yes|no|unknown
  --transfer-slow yes|no|unknown

All checks are read-only. Capture facts are supplied explicitly so this tool
does not start tcpdump or change the firewall.
EOF
}

port="${REALITY_PORT:-}"
syn=unknown
synack=unknown
ack=unknown
accepted=unknown
slow=unknown

valid_tri() {
  case "$1" in yes|no|unknown) return 0 ;; *) return 1 ;; esac
}

tri_status() {
  case "$1" in
    yes) printf pass ;;
    no) printf fail ;;
    *) printf unknown ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --port) [ "$#" -ge 2 ] || { usage_error "--port requires a value"; exit $?; }; port=$2; shift 2 ;;
    --syn-seen) [ "$#" -ge 2 ] || { usage_error "--syn-seen requires a value"; exit $?; }; syn=$2; shift 2 ;;
    --synack-left) [ "$#" -ge 2 ] || { usage_error "--synack-left requires a value"; exit $?; }; synack=$2; shift 2 ;;
    --ack-seen) [ "$#" -ge 2 ] || { usage_error "--ack-seen requires a value"; exit $?; }; ack=$2; shift 2 ;;
    --xray-accepted) [ "$#" -ge 2 ] || { usage_error "--xray-accepted requires a value"; exit $?; }; accepted=$2; shift 2 ;;
    --transfer-slow) [ "$#" -ge 2 ] || { usage_error "--transfer-slow requires a value"; exit $?; }; slow=$2; shift 2 ;;
    *) usage_error "unknown option: $1"; exit $? ;;
  esac
done

if ! require_cmd python3; then
  printf '{"tool":"diagnose-reality","status":"fail","classification":"missing_python3"}\n'
  exit "$VPN_EXIT_DEPENDENCY"
fi
for value in "$syn" "$synack" "$ack" "$accepted" "$slow"; do
  if ! valid_tri "$value"; then
    usage_error "evidence values must be yes, no, or unknown"
    exit $?
  fi
done
case "$port" in ""|*[!0-9]*) [ -n "$port" ] && { usage_error "port must be numeric"; exit $?; } ;; esac

status=warning
classification=evidence_incomplete

if [ -n "$port" ]; then
  if has_cmd ss; then
    if ss -H -ltn 2>/dev/null | awk '{print $4}' | grep -Eq "(^|:)$port$"; then
      add_check listener pass "TCP/${port} is listening"
    else
      add_check listener fail "no TCP listener on ${port}"
      status=fail
      classification=no_tcp_listener
    fi
  elif has_cmd lsof; then
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN 2>/dev/null | grep -q .; then
      add_check listener pass "TCP/${port} is listening"
    else
      add_check listener fail "no TCP listener on ${port}"
      status=fail
      classification=no_tcp_listener
    fi
  else
    add_check listener warning "ss/lsof unavailable; listener not checked"
  fi
else
  add_check listener info "use --port or REALITY_PORT to inspect the listener"
fi

add_check syn "$(tri_status "$syn")" "$syn"
add_check synack "$(tri_status "$synack")" "$synack"
add_check ack "$(tri_status "$ack")" "$ack"
add_check xray-accepted "$(tri_status "$accepted")" "$accepted"

if [ "$syn" = no ]; then
  status=fail
  classification=tcp_not_reaching_server
elif [ "$syn" = yes ] && [ "$synack" = no ]; then
  status=fail
  classification=server_listener_or_firewall
elif [ "$syn" = yes ] && [ "$synack" = yes ] && [ "$ack" = no ]; then
  status=fail
  classification=tcp_return_path_loss
elif [ "$ack" = yes ] && [ "$accepted" = no ]; then
  status=fail
  classification=reality_authentication_or_parameters
elif [ "$accepted" = yes ] && [ "$slow" = yes ]; then
  status=warning
  classification=tcp_throughput_degraded
elif [ "$accepted" = yes ] && [ "$slow" = no ]; then
  status=pass
  classification=transport_healthy
fi

finish_report diagnose-reality "$status" "$classification"
exit $?

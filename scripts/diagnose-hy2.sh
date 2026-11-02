#!/usr/bin/env bash

set -u
# shellcheck source=scripts/lib.sh
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/lib.sh"

usage() {
  cat <<'EOF'
Usage: diagnose-hy2.sh [options]
  --port PORT
  --family 4|6
  --tiny-request yes|no|unknown
  --reply-left yes|no|unknown
  --reply-received yes|no|unknown
  --csum-before N --csum-after N
  --upload-collapse yes|no|unknown

All checks are read-only. Supply observed capture facts to obtain a stable
classification; omitted evidence remains unknown.
EOF
}

port="${HY2_PORT:-}"
family="${HY2_FAMILY:-4}"
request=unknown
reply_left=unknown
reply_received=unknown
upload_collapse=unknown
csum_before=""
csum_after=""

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
    --family) [ "$#" -ge 2 ] || { usage_error "--family requires a value"; exit $?; }; family=$2; shift 2 ;;
    --tiny-request) [ "$#" -ge 2 ] || { usage_error "--tiny-request requires a value"; exit $?; }; request=$2; shift 2 ;;
    --reply-left) [ "$#" -ge 2 ] || { usage_error "--reply-left requires a value"; exit $?; }; reply_left=$2; shift 2 ;;
    --reply-received) [ "$#" -ge 2 ] || { usage_error "--reply-received requires a value"; exit $?; }; reply_received=$2; shift 2 ;;
    --csum-before) [ "$#" -ge 2 ] || { usage_error "--csum-before requires a value"; exit $?; }; csum_before=$2; shift 2 ;;
    --csum-after) [ "$#" -ge 2 ] || { usage_error "--csum-after requires a value"; exit $?; }; csum_after=$2; shift 2 ;;
    --upload-collapse) [ "$#" -ge 2 ] || { usage_error "--upload-collapse requires a value"; exit $?; }; upload_collapse=$2; shift 2 ;;
    *) usage_error "unknown option: $1"; exit $? ;;
  esac
done

if ! require_cmd python3; then
  printf '{"tool":"diagnose-hy2","status":"fail","classification":"missing_python3"}\n'
  exit "$VPN_EXIT_DEPENDENCY"
fi

for value in "$request" "$reply_left" "$reply_received" "$upload_collapse"; do
  if ! valid_tri "$value"; then
    usage_error "evidence values must be yes, no, or unknown"
    exit $?
  fi
done
case "$family" in 4|6) ;; *) usage_error "--family must be 4 or 6"; exit $? ;; esac
case "$port" in ""|*[!0-9]*) [ -n "$port" ] && { usage_error "port must be numeric"; exit $?; } ;; esac
if [ -n "$csum_before$csum_after" ]; then
  case "$csum_before" in ""|*[!0-9]*) usage_error "both checksum counters must be non-negative integers"; exit $? ;; esac
  case "$csum_after" in ""|*[!0-9]*) usage_error "both checksum counters must be non-negative integers"; exit $? ;; esac
fi

status=warning
classification=evidence_incomplete

if [ -n "$port" ]; then
  if has_cmd ss; then
    if ss -H -lun 2>/dev/null | awk '{print $5}' | grep -Eq "(^|:)$port$"; then
      add_check listener pass "UDP/${port} is listening"
    else
      add_check listener fail "no UDP listener on ${port}"
      status=fail
      classification=no_udp_listener
    fi
  else
    add_check listener warning "ss is unavailable; listener not checked"
  fi
else
  add_check listener info "use --port or HY2_PORT to inspect the listener"
fi

if [ -r /proc/net/snmp ]; then
  current_csum=$(awk '
    /^Udp: / {n++; if (n==1) for (i=1;i<=NF;i++) h[i]=$i; else for (i=1;i<=NF;i++) if (h[i]=="InCsumErrors") print $i}
  ' /proc/net/snmp)
  add_check current-udp-checksum-errors info "${current_csum:-unknown}"
else
  add_check current-udp-checksum-errors info "Linux /proc/net/snmp is unavailable"
fi

add_check tiny-request "$(tri_status "$request")" "$request"
add_check reply-left "$(tri_status "$reply_left")" "$reply_left"
add_check reply-received "$(tri_status "$reply_received")" "$reply_received"

delta=""
if [ -n "$csum_before" ] && [ -n "$csum_after" ]; then
  delta=$((csum_after - csum_before))
  if [ "$delta" -gt 0 ]; then
    add_check checksum-delta warning "${delta}"
  else
    add_check checksum-delta pass "${delta}"
  fi
fi

if [ "$request" = no ]; then
  status=fail
  classification=udp_not_reaching_server
elif [ "$request" = yes ] && [ "$reply_left" = no ]; then
  status=fail
  classification=server_listener_or_firewall
elif [ "$request" = yes ] && [ "$reply_left" = yes ] && [ "$reply_received" = no ] && [ "${delta:-0}" -eq 0 ]; then
  status=fail
  if [ "$family" = 4 ]; then
    classification=ipv4_udp_return_path_loss
  else
    classification=ipv6_udp_return_path_loss
  fi
elif [ "$request" = yes ] && [ "$reply_received" = yes ] && [ "${delta:-0}" -gt 0 ]; then
  status=fail
  classification=large_packet_checksum_corruption
elif [ "$request" = yes ] && [ "$reply_left" = yes ] && [ "$reply_received" = yes ] && [ "$upload_collapse" = yes ]; then
  status=warning
  classification=client_upload_pacing
elif [ "$request" = yes ] && [ "$reply_left" = yes ] && [ "$reply_received" = yes ] && [ "${delta:-0}" -eq 0 ]; then
  status=pass
  classification=transport_healthy
fi

finish_report diagnose-hy2 "$status" "$classification" "{\"family\":${family}}"
exit $?

#!/usr/bin/env bash

set -u
# shellcheck source=scripts/lib.sh
. "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/lib.sh"

usage() {
  cat <<'EOF'
Usage: acceptance.sh [options]
  --expected-exit IP
  --ip-url URL                 default: https://api.ipify.org
  --download-url URL
  --min-bytes N               required with --download-url
  --timeout SECONDS           default: 30

The script performs read-only HTTP requests. It does not select a proxy, reload
a profile or change routing. JSON goes to stdout and is automatically redacted.
EOF
}

expected=""
ip_url="https://api.ipify.org"
download_url=""
min_bytes=""
timeout=30

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --expected-exit) [ "$#" -ge 2 ] || { usage_error "--expected-exit requires a value"; exit $?; }; expected=$2; shift 2 ;;
    --ip-url) [ "$#" -ge 2 ] || { usage_error "--ip-url requires a value"; exit $?; }; ip_url=$2; shift 2 ;;
    --download-url) [ "$#" -ge 2 ] || { usage_error "--download-url requires a value"; exit $?; }; download_url=$2; shift 2 ;;
    --min-bytes) [ "$#" -ge 2 ] || { usage_error "--min-bytes requires a value"; exit $?; }; min_bytes=$2; shift 2 ;;
    --timeout) [ "$#" -ge 2 ] || { usage_error "--timeout requires a value"; exit $?; }; timeout=$2; shift 2 ;;
    *) usage_error "unknown option: $1"; exit $? ;;
  esac
done

if ! require_cmd python3 || ! require_cmd curl; then
  printf '{"tool":"acceptance","status":"fail","classification":"missing_dependency"}\n'
  exit "$VPN_EXIT_DEPENDENCY"
fi
case "$timeout" in *[!0-9]*|"") usage_error "--timeout must be a positive integer"; exit $? ;; esac
if [ -n "$download_url" ]; then
  case "$min_bytes" in *[!0-9]*|"") usage_error "--min-bytes must be set to an integer with --download-url"; exit $? ;; esac
elif [ -n "$min_bytes" ]; then
  usage_error "--download-url is required with --min-bytes"
  exit $?
fi

status=pass
classification=accepted
tests=0

if [ -n "$expected" ]; then
  tests=$((tests + 1))
  actual=$(curl --fail --silent --show-error --max-time "$timeout" "$ip_url" 2>/dev/null | tr -d '[:space:]')
  if [ "$actual" = "$expected" ]; then
    add_check exit-address pass "observed expected exit ${actual}"
  elif [ -z "$actual" ]; then
    add_check exit-address fail "exit address endpoint did not return a value"
    status=fail
    classification=exit_check_failed
  else
    add_check exit-address fail "expected ${expected}, observed ${actual}"
    status=fail
    classification=wrong_exit
  fi
else
  add_check exit-address info "not tested; pass --expected-exit"
fi

if [ -n "$download_url" ]; then
  tests=$((tests + 1))
  curl_result=$(curl --fail --location --silent --show-error --output /dev/null \
    --max-time "$timeout" --write-out '%{size_download}|%{http_code}|%{time_total}' \
    "$download_url" 2>/dev/null)
  curl_code=$?
  size=$(printf '%s' "$curl_result" | cut -d '|' -f 1)
  http_code=$(printf '%s' "$curl_result" | cut -d '|' -f 2)
  total=$(printf '%s' "$curl_result" | cut -d '|' -f 3)
  case "$size" in *[!0-9]*|"") size=0 ;; esac
  if [ "$curl_code" -eq 0 ] && [ "$size" -ge "$min_bytes" ]; then
    add_check fixed-download pass "${size} bytes, HTTP ${http_code}, ${total}s"
  else
    add_check fixed-download fail "${size} bytes, HTTP ${http_code:-unknown}, curl=${curl_code}"
    status=fail
    classification=fixed_transfer_failed
  fi
else
  add_check fixed-download info "not tested; pass --download-url and --min-bytes"
fi

if [ "$tests" -eq 0 ]; then
  status=warning
  classification=no_acceptance_targets
fi

finish_report acceptance "$status" "$classification" "{\"tests_run\":${tests}}"
exit $?

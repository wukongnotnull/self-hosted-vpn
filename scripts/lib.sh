#!/usr/bin/env bash

# Shared helpers. Diagnostic scripts intentionally do not use `set -e` so every
# safe check can run and appear in the report.

# shellcheck disable=SC2034
VPN_EXIT_PASS=0
VPN_EXIT_WARNING=10
VPN_EXIT_FAIL=20
VPN_EXIT_USAGE=64
VPN_EXIT_DEPENDENCY=69
VPN_EXIT_PERMISSION=77

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPORTER="${SCRIPT_DIR}/report.py"
CHECKS=()

add_check() {
  local name=$1
  local state=$2
  local detail=$3
  CHECKS+=("${name}|${state}|${detail}")
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  if has_cmd "$1"; then
    add_check "dependency:$1" pass "available"
    return 0
  fi
  add_check "dependency:$1" fail "missing"
  return 1
}

finish_report() {
  local tool=$1
  local status=$2
  local classification=$3
  local metadata=${4:-"{}"}
  local args=(--tool "$tool" --status "$status" --classification "$classification" --metadata "$metadata")
  for check in "${CHECKS[@]}"; do
    args+=(--check "$check")
  done
  python3 "$REPORTER" "${args[@]}"

  case "$status" in
    pass) return "$VPN_EXIT_PASS" ;;
    warning) return "$VPN_EXIT_WARNING" ;;
    fail) return "$VPN_EXIT_FAIL" ;;
    *) return "$VPN_EXIT_USAGE" ;;
  esac
}

usage_error() {
  printf '%s\n' "$1" >&2
  return "$VPN_EXIT_USAGE"
}

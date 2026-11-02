#!/usr/bin/env bash

set -u
# shellcheck source=scripts/lib.sh
. "$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/lib.sh"

usage() {
  cat <<'EOF'
Usage: make-test-file.sh --output PATH --bytes N [--confirm]

Creates deterministic test data for fixed-size transfer checks. The destination
must not exist. --confirm is required because this script writes a file.
EOF
}

output=""
bytes=""
confirm=no
while [ "$#" -gt 0 ]; do
  case "$1" in
    --help) usage; exit 0 ;;
    --output) [ "$#" -ge 2 ] || { usage_error "--output requires a value"; exit $?; }; output=$2; shift 2 ;;
    --bytes) [ "$#" -ge 2 ] || { usage_error "--bytes requires a value"; exit $?; }; bytes=$2; shift 2 ;;
    --confirm) confirm=yes; shift ;;
    *) usage_error "unknown option: $1"; exit $? ;;
  esac
done

if ! require_cmd python3; then
  printf '{"tool":"make-test-file","status":"fail","classification":"missing_python3"}\n'
  exit "$VPN_EXIT_DEPENDENCY"
fi
case "$bytes" in *[!0-9]*|"") usage_error "--bytes must be a positive integer"; exit $? ;; esac
if [ "$bytes" -le 0 ] || [ -z "$output" ]; then
  usage_error "--output and a positive --bytes are required"
  exit $?
fi
if [ "$confirm" != yes ]; then
  add_check confirmation fail "pass --confirm after reviewing output path and size"
  finish_report make-test-file fail confirmation_required
  exit $?
fi
if [ -e "$output" ]; then
  add_check destination fail "refusing to overwrite existing path: ${output}"
  finish_report make-test-file fail destination_exists
  exit $?
fi

if python3 - "$output" "$bytes" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
size = int(sys.argv[2])
block = bytes(range(256)) * 256
with path.open("xb") as handle:
    remaining = size
    while remaining:
        chunk = block[: min(remaining, len(block))]
        handle.write(chunk)
        remaining -= len(chunk)
PY
then
  add_check generated pass "${bytes} bytes at ${output}"
  finish_report make-test-file pass generated "{\"bytes\":${bytes}}"
  exit $?
fi

add_check generated fail "file creation failed"
finish_report make-test-file fail write_failed
exit $?

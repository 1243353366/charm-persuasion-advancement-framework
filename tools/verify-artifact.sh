#!/usr/bin/env bash
# Verify that a binary claiming to be a darkscan scanner really is one.
#
# Usage:
#   tools/verify-artifact.sh <binary>                # rebuild from source and compare
#   tools/verify-artifact.sh <binary> <sha256>       # compare against a known-good hash
#
# The rebuild comparison is the strong check: it does not trust any hash file,
# any website, or any signature you have not independently anchored.
set -uo pipefail
cd "$(dirname "$0")/.."

artifact=${1:-}
expected=${2:-}
[ -z "$artifact" ] && { echo "usage: tools/verify-artifact.sh <binary> [sha256]" >&2; exit 2; }
[ -f "$artifact" ] || { echo "error: no such file: $artifact" >&2; exit 2; }

have=$(sha256sum "$artifact" | cut -d' ' -f1)
echo "artifact: $artifact"
echo "sha256:   $have"

if [ -n "$expected" ]; then
  if [ "$have" = "$expected" ]; then
    echo "MATCH — hash equals the expected value you supplied."
    echo "(This is only as trustworthy as the channel you got that value from.)"
    exit 0
  fi
  echo "MISMATCH — expected $expected"
  echo "Do not run this file."
  exit 1
fi

echo
echo "No expected hash supplied: rebuilding from source and comparing."
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cc=${CC:-cc}
matched=""

if [ -f darkpatterns/c/darkscan.c ] && command -v "$cc" >/dev/null 2>&1; then
  "$cc" -std=c11 -O2 -o "$work/darkscan-c" darkpatterns/c/darkscan.c
  h=$(sha256sum "$work/darkscan-c" | cut -d' ' -f1)
  echo "rebuilt c:  $h"
  [ "$h" = "$have" ] && matched="c"
fi

if [ -f darkpatterns/go/darkscan.go ] && command -v go >/dev/null 2>&1; then
  ( cd darkpatterns/go && go build -trimpath -buildvcs=false -ldflags='-s -w' -o "$work/darkscan-go" darkscan.go )
  h=$(sha256sum "$work/darkscan-go" | cut -d' ' -f1)
  echo "rebuilt go: $h"
  [ "$h" = "$have" ] && matched="go"
fi

echo
if [ -n "$matched" ]; then
  echo "MATCH — this artifact is byte-identical to a fresh $matched build from this source tree."
  exit 0
fi
echo "NO MATCH — this artifact does not correspond to any source in this tree."
echo "Treat it as untrusted: do not run it, and do not report it as this tool."
exit 1

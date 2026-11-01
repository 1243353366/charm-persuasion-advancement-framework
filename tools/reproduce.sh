#!/usr/bin/env bash
# Reproducible-build check: build each implementation twice, compare hashes.
# Identical hashes mean a third party can rebuild your binary and verify it.
set -uo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
fail=0

CC=${CC:-cc}
if command -v "$CC" >/dev/null 2>&1; then
  "$CC" -std=c11 -Wall -Wextra -Werror -O2 -o "$work/c1" darkpatterns/c/darkscan.c
  "$CC" -std=c11 -Wall -Wextra -Werror -O2 -o "$work/c2" darkpatterns/c/darkscan.c
  h1=$(sha256sum "$work/c1" | cut -d' ' -f1)
  h2=$(sha256sum "$work/c2" | cut -d' ' -f1)
  if [ "$h1" = "$h2" ]; then
    echo "OK   c: reproducible build ($h1)"
  else
    echo "FAIL c: builds differ ($h1 vs $h2)"; fail=1
  fi
else
  echo "skip c: no compiler"
fi

if command -v go >/dev/null 2>&1; then
  ( cd darkpatterns/go
    go build -trimpath -buildvcs=false -ldflags='-s -w' -o "$work/g1" darkscan.go
    go build -trimpath -buildvcs=false -ldflags='-s -w' -o "$work/g2" darkscan.go )
  h1=$(sha256sum "$work/g1" | cut -d' ' -f1)
  h2=$(sha256sum "$work/g2" | cut -d' ' -f1)
  if [ "$h1" = "$h2" ]; then
    echo "OK   go: reproducible build ($h1)"
  else
    echo "FAIL go: builds differ ($h1 vs $h2)"; fail=1
  fi
else
  echo "skip go: toolchain not installed"
fi

echo "note: java and python run from source; there is no binary to reproduce."
exit $fail

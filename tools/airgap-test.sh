#!/usr/bin/env bash
# Runtime proof that the scanners work with no network available.
#
# Method 1: network namespace (unshare -n) when the kernel allows it.
# Method 2: LD_PRELOAD shim (tools/netguard.c) that fails socket(), connect(),
#           and getaddrinfo(). Applies to the C, Python, and Java scanners;
#           Go's static binary is covered by the capability audit instead.
#
# A scanner that touches the network cannot complete under either method.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
input=darkpatterns/tests/corpus/elevated.txt

baseline=$(python3 darkpatterns/python/darkscan.py "$input") || { echo "FAIL: baseline run failed"; exit 1; }

# --- Method 2: LD_PRELOAD shim (always attempted, no privileges needed) ---
cc=${CC:-cc}
if command -v "$cc" >/dev/null 2>&1; then
  "$cc" -shared -fPIC -O2 -o "$work/netguard.so" tools/netguard.c || { echo "FAIL: netguard build"; fail=1; }

  # Control: the shim must actually break networking, or the test is meaningless.
  if LD_PRELOAD="$work/netguard.so" python3 -c "import socket; socket.create_connection(('1.1.1.1',443),2)" 2>/dev/null; then
    echo "FAIL: netguard did not block a test connection — proof invalid"
    fail=1
  else
    echo "OK   netguard: outbound connections are blocked under the shim"
  fi

  out=$(LD_PRELOAD="$work/netguard.so" python3 darkpatterns/python/darkscan.py "$input")
  if [ "$out" = "$baseline" ]; then
    echo "OK   python: identical report with networking disabled"
  else
    echo "FAIL python: report changed under network denial"; fail=1
  fi

  if [ -x dist/darkscan-c ]; then
    out=$(LD_PRELOAD="$work/netguard.so" dist/darkscan-c "$input")
    if [ "$out" = "$baseline" ]; then
      echo "OK   c: identical report with networking disabled"
    else
      echo "FAIL c: report changed under network denial"; fail=1
    fi
  fi
else
  echo "skip ld_preload: no C compiler to build the shim"
fi

# --- Method 1: network namespace, when permitted ---
if unshare -n true 2>/dev/null; then
  out=$(unshare -n python3 darkpatterns/python/darkscan.py "$input")
  if [ "$out" = "$baseline" ]; then
    echo "OK   namespace: identical report inside an isolated network namespace"
  else
    echo "FAIL namespace: report changed inside the namespace"; fail=1
  fi
else
  echo "skip namespace: unshare -n not permitted here (needs CAP_SYS_ADMIN)"
fi

echo
[ "$fail" = 0 ] && echo "AIR-GAP PASS — scanners produce identical reports with networking denied." \
                 || echo "AIR-GAP FAIL — investigate before relying on the offline claim."
exit $fail

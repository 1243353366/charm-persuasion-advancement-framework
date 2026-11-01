#!/usr/bin/env bash
# Supply-chain integrity gate for the Layer 14 scanners.
#
# Checks, in order:
#   1. MANIFEST.sha256 — every listed file still matches its recorded hash
#   2. no committed build artifacts (ELF, PE, Mach-O, class, jar, .so, …)
#   3. capability floor — scanners contain no network, write, or exec APIs
#
# Exit 0 = clean, 1 = something needs review. Pure bash + coreutils + grep.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
note() { printf '%-4s %s\n' "$1" "$2"; }

# ---- 1. Manifest ----------------------------------------------------------
if [ ! -f MANIFEST.sha256 ]; then
  note FAIL "manifest: MANIFEST.sha256 missing (run tools/make-manifest.sh)"
  fail=1
elif sha256sum -c --quiet MANIFEST.sha256 >/dev/null 2>&1; then
  note OK "manifest: all $(wc -l < MANIFEST.sha256) listed files match their hashes"
else
  note FAIL "manifest: one or more files differ from MANIFEST.sha256"
  sha256sum -c MANIFEST.sha256 2>&1 | grep -v ': OK$' | sed 's/^/     /'
  fail=1
fi

# Unlisted files (warning only: a user may add CI config or notes)
listed=$(awk '{print $2}' MANIFEST.sha256 2>/dev/null | LC_ALL=C sort)
present=$(find . -path ./.git -prune -o -path ./dist -prune -o -path ./__pycache__ -prune \
  -o -type f -print 2>/dev/null | sed 's|^\./||' | grep -v '^MANIFEST.sha256$' \
  | grep -v '^\.github/' | LC_ALL=C sort)
extra=$(comm -13 <(printf '%s\n' "$listed") <(printf '%s\n' "$present") 2>/dev/null || true)
if [ -n "$extra" ]; then
  note WARN "manifest: files present but not recorded (review them):"
  printf '%s\n' "$extra" | sed 's/^/     /'
fi

# ---- 2. No committed build artifacts --------------------------------------
byname=$(find . -path ./.git -prune -o -path ./dist -prune -o -type f \( \
  -name '*.class' -o -name '*.jar' -o -name '*.exe' -o -name '*.dll' \
  -o -name '*.so' -o -name '*.dylib' -o -name '*.o' -o -name '*.a' \
  -o -name '*.pyc' -o -name '*.bin' \) -print 2>/dev/null)
if [ -n "$byname" ]; then
  note FAIL "artifacts: compiled files present in the tree"
  printf '%s\n' "$byname" | sed 's/^/     /'
  fail=1
else
  note OK "artifacts: no compiled files in the tree"
fi

# Magic-byte scan (catches binaries with innocent names)
magic=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  h=$(head -c 4 "$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')
  case "$h" in
    7f454c46|cffaedfe|cafebabe|feedface|feedfacf|4d5a*) magic="$magic $f" ;;
  esac
done < <(find . -path ./.git -prune -o -path ./dist -prune -o -type f -size +0c -print 2>/dev/null)
if [ -n "$magic" ]; then
  note FAIL "artifacts: binary content detected (ELF/PE/Mach-O/class magic):"
  for f in $magic; do echo "     $f"; done
  fail=1
else
  note OK "artifacts: no binary content by magic bytes"
fi

# ---- 3. Capability floor --------------------------------------------------
# The scanners must never gain network, write, or exec capability. If any of
# these patterns appear, a capability was added and needs review — that is the
# whole point: a trojanized build cannot exfiltrate without leaving this mark.
NET='net/http|net\.Dial|net\.Listen|socket\(|getaddrinfo|urllib|http\.client|requests\.(get|post)|java\.net\.|HttpClient|URLConnection|WebSocket'
WRITE='fopen\([^)]*"[wa]|freopen\(|O_WRONLY|O_CREAT|O_RDWR|os\.Create|os\.WriteFile|ioutil\.WriteFile|Files\.write|FileOutputStream|FileWriter|PrintWriter|RandomAccessFile|open\([^)]*["'"'"'][wa]'
EXEC='os/exec|exec\.Command|subprocess|Runtime\.getRuntime|ProcessBuilder|system\(|popen|execl|execv|fork\('

for src in darkpatterns/go/darkscan.go darkpatterns/java/DarkScan.java \
           darkpatterns/python/darkscan.py darkpatterns/c/darkscan.c; do
  [ -f "$src" ] || { note FAIL "capability: $src missing"; fail=1; continue; }
done

cap_fail=0
for src in darkpatterns/go/darkscan.go darkpatterns/java/DarkScan.java \
           darkpatterns/python/darkscan.py darkpatterns/c/darkscan.c; do
  for kind in NET WRITE EXEC; do
    pat=${!kind}
    if hits=$(grep -nE "$pat" "$src" 2>/dev/null); then
      note FAIL "capability: $src gained a $kind capability"
      printf '%s\n' "$hits" | sed 's/^/     /'
      cap_fail=1; fail=1
    fi
  done
done
[ "$cap_fail" = 0 ] && note OK "capability: scanners are network-free, write-free, exec-free"

echo
if [ "$fail" = 0 ]; then
  echo "VERIFY PASS — tree matches manifest, no binaries, capability floor intact."
else
  echo "VERIFY FAIL — review the findings above before trusting this checkout."
fi
exit $fail

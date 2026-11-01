#!/usr/bin/env bash
# Handle a Layer 14 report safely — for journalists, activists, and anyone
# whose case details are themselves sensitive.
#
# What it does:
#   * writes the report with 0600 permissions (override the umask, not the file)
#   * echoes ONLY the one-line risk summary to your terminal
#   * reads the interaction from stdin by default: nothing in a temp file,
#     nothing left behind, nothing in shell history if you pipe it
#
# Usage:
#   printf '...' | tools/safe-report.sh <c|go|python|java> <report-file>
#   tools/safe-report.sh c ~/secure/case-2026-11-01.txt < case.txt
#
# The report file is still sensitive: it names the tactics involved in your
# situation, which can imply who and what. Keep it on encrypted storage.
set -euo pipefail
cd "$(dirname "$0")/.."

scanner=${1:-}
report=${2:-}
if [ -z "$scanner" ] || [ -z "$report" ]; then
  echo "usage: tools/safe-report.sh <c|go|python|java> <report-file>" >&2
  echo "       (scanner reads the interaction from stdin)" >&2
  exit 2
fi

case "$scanner" in
  c)      cmd=(dist/darkscan-c) ;;
  go)     cmd=(dist/darkscan-go) ;;
  python) cmd=(python3 darkpatterns/python/darkscan.py) ;;
  java)   cmd=(java darkpatterns/java/DarkScan.java) ;;
  *) echo "error: unknown scanner '$scanner'" >&2; exit 2 ;;
esac

if [ ! -x "${cmd[0]}" ] && [ "${cmd[0]}" != "python3" ] && [ "${cmd[0]}" != "java" ]; then
  echo "error: ${cmd[0]} not built. Run tools/build.sh first." >&2
  exit 1
fi

# umask 077 → the report is created 0600 (owner read/write only)
( umask 077; "${cmd[@]}" - >"$report" )
chmod 600 "$report"

summary=$(grep -m1 '^Risk summary:' "$report" || true)
echo "report written: $report (mode 600)"
echo "${summary:-check the report: no summary line found}"
echo
echo "Reminder: the report stays sensitive — it names the tactics in play."
echo "Share the summary line, not the file. Store it encrypted (age, gpg, LUKS)."
echo "Compose the input in a pipe or an editor; avoid leaving it in shell history."

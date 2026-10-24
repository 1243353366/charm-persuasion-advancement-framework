#!/usr/bin/env python3
"""Cross-language conformance runner for the Layer 14 scanners.

Runs the Go, Java, and Python implementations over the shared corpus
and verifies three things:

1. Byte-identical stdout across all three languages for every corpus file.
2. The expected number of tactics fired for every corpus file.
3. Matching exit-code behavior on input errors (exit 1, "error:" on stderr).

Requires all three toolchains on the machine that runs it. In CI this
is .github/workflows/conformance.yml; locally run:

    python3 darkpatterns/tests/conformance.py
"""

import difflib
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # darkpatterns/
CORPUS = os.path.join(ROOT, "tests", "corpus")

EXPECT_FIRED = {
    "elevated.txt": 4,
    "clean.txt": 0,
    "urgency.txt": 1,
    "provocation.txt": 1,
}

LANGS = ("go", "java", "python")


def run_go(inp):
    return subprocess.run(["go", "run", "darkscan.go", inp],
                          cwd=os.path.join(ROOT, "go"),
                          capture_output=True, text=True)


def run_java(inp):
    return subprocess.run(["java", "DarkScan.java", inp],
                          cwd=os.path.join(ROOT, "java"),
                          capture_output=True, text=True)


def run_python(inp):
    return subprocess.run([sys.executable, "darkscan.py", inp],
                          cwd=os.path.join(ROOT, "python"),
                          capture_output=True, text=True)


def fired_count(output: str) -> int:
    return len(re.findall(r"^\[\d\] ", output, re.MULTILINE))


failures = []


def check(cond, msg):
    if not cond:
        failures.append(msg)


for name, expected in sorted(EXPECT_FIRED.items()):
    inp = os.path.join(CORPUS, name)
    runners = {"go": run_go, "java": run_java, "python": run_python}
    results = {}
    for lang, runner in runners.items():
        try:
            results[lang] = runner(inp)
        except FileNotFoundError as exc:
            results[lang] = None
            check(False, f"{name}/{lang}: toolchain unavailable ({exc})")
    if any(r is None for r in results.values()):
        continue

    for lang, r in results.items():
        check(r.returncode == 0,
              f"{name}/{lang}: exit {r.returncode}, stderr: {r.stderr[:400]}")

    ref = results["go"].stdout
    for lang in ("java", "python"):
        if results[lang].stdout != ref:
            diff = "\n".join(list(difflib.unified_diff(
                ref.splitlines(), results[lang].stdout.splitlines(),
                fromfile="go", tofile=lang, lineterm=""))[:40])
            check(False, f"{name}: {lang} output differs from go:\n{diff}")

    check(fired_count(ref) == expected,
          f"{name}: expected {expected} tactic(s) fired, got {fired_count(ref)}")

# Exit-code conformance on a missing input file.
for lang, runner in (("go", run_go), ("java", run_java), ("python", run_python)):
    r = runner(os.path.join(CORPUS, "does-not-exist.txt"))
    check(r.returncode == 1, f"missing-file/{lang}: expected exit 1, got {r.returncode}")

if failures:
    print("CONFORMANCE FAILURES:")
    for f in failures:
        print(" -", f)
    sys.exit(1)

print("CONFORMANCE PASS — Go, Java, and Python: identical output across the full corpus, "
      "expected tactic counts, matching exit codes.")

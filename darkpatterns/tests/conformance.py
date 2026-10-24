#!/usr/bin/env python3
"""Cross-language conformance runner for the Layer 14 scanners.

Runs every implementation whose toolchain is available (Go, Java, Python, C)
over the shared corpus and verifies three things:

1. Byte-identical stdout across every implementation that ran.
2. The expected number of tactics fired for every corpus file.
3. Matching exit-code behavior on input errors (exit 1).

At least two toolchains must be available, so outputs can be compared.
In CI this is .github/workflows/conformance.yml; locally run:

    python3 darkpatterns/tests/conformance.py
"""

import difflib
import os
import re
import shutil
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


def fired_count(output: str) -> int:
    return len(re.findall(r"^\[\d\] ", output, re.MULTILINE))


def run_cmd(cmd, cwd=None, inp=None):
    return subprocess.run(cmd, cwd=cwd, input=inp, capture_output=True, text=True)


class Runner:
    def __init__(self, lang):
        self.lang = lang
        self.available = False
        self.skip_reason = ""

    def run(self, inp_path, stdin_text=None):
        raise NotImplementedError


class GoRunner(Runner):
    def __init__(self):
        super().__init__("go")
        self.available = shutil.which("go") is not None
        if not self.available:
            self.skip_reason = "go toolchain not installed"

    def run(self, inp_path, stdin_text=None):
        r = run_cmd(["go", "run", "darkscan.go", inp_path], cwd=os.path.join(ROOT, "go"))
        return r


class JavaRunner(Runner):
    def __init__(self):
        super().__init__("java")
        self.available = shutil.which("java") is not None
        if not self.available:
            self.skip_reason = "java runtime not installed"

    def run(self, inp_path, stdin_text=None):
        return run_cmd(["java", "DarkScan.java", inp_path], cwd=os.path.join(ROOT, "java"))


class PythonRunner(Runner):
    def __init__(self):
        super().__init__("python")
        self.available = True

    def run(self, inp_path, stdin_text=None):
        return run_cmd([sys.executable, "darkscan.py", inp_path],
                       cwd=os.path.join(ROOT, "python"))


class CRunner(Runner):
    def __init__(self):
        super().__init__("c")
        cc = shutil.which("cc") or shutil.which("gcc") or shutil.which("clang")
        self.available = cc is not None
        self.cc = cc
        if not self.available:
            self.skip_reason = "no C compiler (cc/gcc/clang) installed"
        self.exe = "/tmp/darkscan-c"

    def ensure_built(self):
        src = os.path.join(ROOT, "c", "darkscan.c")
        if (not os.path.exists(self.exe)
                or os.path.getmtime(self.exe) < os.path.getmtime(src)):
            build = run_cmd([self.cc, "-std=c11", "-Wall", "-Wextra", "-Werror",
                             "-O2", "-o", self.exe, "darkscan.c"],
                            cwd=os.path.join(ROOT, "c"))
            if build.returncode != 0:
                raise RuntimeError(f"C build failed: {build.stderr[:400]}")

    def run(self, inp_path, stdin_text=None):
        self.ensure_built()
        return run_cmd([self.exe, inp_path])


failures = []
skipped = []
runners = [GoRunner(), JavaRunner(), PythonRunner(), CRunner()]
active = []
for r in runners:
    if r.available:
        active.append(r)
    else:
        skipped.append(f"{r.lang} (skipped: {r.skip_reason})")

if len(active) < 2:
    print("CONFORMANCE FAIL: need at least two implementations with toolchains "
          f"available to compare; found {[r.lang for r in active]}.")
    sys.exit(1)

for name, expected in sorted(EXPECT_FIRED.items()):
    inp = os.path.join(CORPUS, name)
    outputs = {}
    for r in active:
        try:
            outputs[r.lang] = r.run(inp)
        except RuntimeError as exc:
            failures.append(f"{name}/{r.lang}: {exc}")
            outputs.pop(r.lang, None)
    if not outputs:
        continue

    for lang, res in outputs.items():
        if res.returncode != 0:
            failures.append(f"{name}/{lang}: exit {res.returncode}, stderr: {res.stderr[:400]}")
    outputs = {lang: res for lang, res in outputs.items() if res.returncode == 0}
    if not outputs:
        continue

    ref_lang, ref_res = next(iter(outputs.items()))
    for lang, res in outputs.items():
        if res.stdout != ref_res.stdout:
            diff = "\n".join(list(difflib.unified_diff(
                ref_res.stdout.splitlines(), res.stdout.splitlines(),
                fromfile=ref_lang, tofile=lang, lineterm=""))[:40])
            failures.append(f"{name}: {lang} output differs from {ref_lang}:\n{diff}")

    count = fired_count(ref_res.stdout)
    if count != expected:
        failures.append(f"{name}: expected {expected} tactic(s) fired, got {count}")

# Exit-code conformance on a missing input file.
for r in active:
    try:
        res = r.run(os.path.join(CORPUS, "does-not-exist.txt"))
        if res.returncode != 1:
            failures.append(f"missing-file/{r.lang}: expected exit 1, got {res.returncode}")
    except RuntimeError as exc:
        failures.append(f"missing-file/{r.lang}: {exc}")

for s in skipped:
    print(" ", s)

if failures:
    print("CONFORMANCE FAILURES:")
    for f in failures:
        print(" -", f)
    sys.exit(1)

print(f"CONFORMANCE PASS — {[r.lang for r in active]} outputs identical across the full "
      "corpus, expected tactic counts, matching exit codes.")

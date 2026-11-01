# Security Policy — Supply-Chain Integrity

This repository ships **four single-file scanners and no binaries**. That design choice is the core of its supply-chain defense: there is nothing prebuilt to trojanize, and every build a user runs is one they compiled themselves in seconds.

## Threat model

| Attack | Vector | Effect here |
|---|---|---|
| Compromised upstream repo | Attacker pushes malicious source, or rewrites history | **Detectable, not preventable from inside the repo.** Mitigated by manifest verification, diff review, commit-hash pinning, and independent mirrors. |
| Substituted compiled binary | Attacker distributes a "release build" under this tool's name | **No legitimate binary exists to substitute.** There are no releases, no dist artifacts, no package-registry builds. A binary claiming to be darkscan is unfalsifiable by definition — build from source instead. |
| Dependency-chain attack | Compromised transitive dependency | **No dependency surface.** Go: stdlib only, no `go.mod` deps. Java: `java.io`/`java.nio`/`java.util` only. Python: stdlib only. C: libc only. |
| Silent capability upgrade | Trojanized build exfiltrates or persists | **Capability floor, machine-checked.** The scanners perform no network I/O, no file writes, no process execution. `tools/verify.sh` fails the tree if any of those capabilities appear in source, so adding one is a visible, reviewable event. |
| Build-time compromise | Malicious build step injects code | **Reproducible build.** `tools/reproduce.sh` builds twice and compares hashes; a mismatched build is a tampering signal. |
| Impersonation / lookalike distribution | Someone offers a "darkscan installer", .exe, .dmg, or a similarly named repo | **There is nothing to install.** No releases, no installers, no binaries exist under this project's name. Anything offered as a download is not this tool. |
| Sensitive report exposure | A report is stored insecurely, synced, or leaked | **Reports contain no input data** — no paths, usernames, or excerpts; enforced by a privacy regression test. Residual risk is the *tactic list itself*, which can imply who and what. |

## What each defense actually buys

1. **No binaries in the repository.** `.gitignore` excludes `dist/` and all compiled artifacts; `tools/verify.sh` fails if a binary (ELF, PE, Mach-O, class file, jar) ever appears in the tree. The "download the tool" habit is replaced by "compile the tool" — one command, no dependencies.
2. **Reproducible builds.** Go is built with `-trimpath -buildvcs=false`; C with fixed flags. Two builds of the same source produce identical hashes, so a user can rebuild and compare against any binary someone hands them. If the hashes differ, the binary is not this tool.
3. **Capability minimization, enforced.** The scanners read one input file (or stdin) and write to stdout. Nothing else. `tools/verify.sh` greps the four scanner sources for network, filesystem-write, and process-execution APIs and fails on any hit. A compromised commit that adds exfiltration must also visibly add `net/http`, `java.net`, `urllib`, `socket()`, or similar — and that shows up in `git diff` and in this gate.
4. **Manifest verification.** `MANIFEST.sha256` records the hash of every source and doc file. `tools/verify.sh` checks the tree against it. A one-byte change anywhere is detectable.
5. **Commit-hash pinning.** Consumers should vendor a specific commit, not track `main`: `git clone … && git checkout <sha>`. Combined with `git verify-commit` where commits are signed, silent upstream drift stops mattering.

## If someone offers you this tool as a download

This project ships **no installers, no releases, and no binaries**. There is no `.exe`, `.dmg`, `.tar.gz`, or app bundle with this name, and no package on any registry. That is deliberate: a tool with nothing to install cannot be impersonated by an installer.

- **A file claiming to be darkscan is not this project.** If you received a binary, an "installer", or a repo that merely looks similar, you have the impersonation attempt, not the tool.
- **Verify provenance, not vibes.** Clone the repo, pin a commit (`git checkout <sha>`), and check `MANIFEST.sha256` against the copy whose own hash you obtained out of band. Then read the diff since your last pinned commit. That is the whole verification story — no artifact to trust.
- **Signed checksums beat unsigned ones.** A `SHA256SUMS` file served from the same host as the download proves nothing if that host is compromised; both can be swapped together. Only a detached signature (GPG/minisign) verified against a key fingerprint obtained through a *different* channel establishes origin. If this project ever ships binaries, they will be signed, with the fingerprint published independently of the repo.
- **Prefer source over artifacts.** `python3 darkpatterns/python/darkscan.py`, `cc` the C file, or build with `tools/build.sh`. Every implementation is one file you can read end to end.

## Verifying a checkout

```bash
tools/verify.sh        # manifest + no-binaries + capability audit
tools/reproduce.sh     # double-build determinism check
tools/build.sh         # canonical build, prints artifact hashes
```

All three are pure shell and need no toolchains beyond the ones they test for; `verify.sh` alone needs only bash, coreutils, and grep.

## Reporting on sensitive material

**Reports are minimal by design, and the minimum is machine-checked.** A report contains only: a header, one five-field record per fired tactic (static text from the rule table), the fired-tactic count, and two closing notes. It contains **no input data** — no field values, no file paths, no usernames, no message excerpts. `darkpatterns/tests/conformance.py` enforces this: every corpus case carrying `context_*` keys has those values asserted absent from every implementation's output, for every language, and the run fails if any implementation begins echoing input.

Verified behavior:
- **No echo, ever.** Field values are parsed for rule evaluation and discarded; only counts and static text reach stdout.
- **Nothing leaves the machine.** No network, no writes, no telemetry (capability floor, `tools/verify.sh`).
- **The error path** prints the input filename to your terminal if a file cannot be opened; it never enters a report. If the filename itself is sensitive (a case name, a source's name), feed input on stdin (`-`) instead of passing a path.

### Guidance for high-risk users

Journalists, activists, researchers, and anyone whose case details are themselves sensitive:

- **Pipe the interaction in; don't write it to disk.** `printf '…' | tools/safe-report.sh c ~/secure/case.txt` — no temp file, nothing to shred.
- **Use `tools/safe-report.sh`.** It writes the report `0600` and prints only the one-line risk summary, so a report can sit on screen in front of someone else.
- **Share the summary, not the record.** The full record names which tactics were detected in your situation. That list is often enough to imply who and what, even with no names in it.
- **Your case notes are the real exposure surface.** The scanner's output is deliberately low-detail; the context you write around it — names, dates, what happened — is the sensitive artifact. Keep it encrypted, off synced drives, and delete it when the case closes.
- **Run offline.** Nothing here needs a network. An air-gapped run removes the accidental-exfiltration path entirely.
- **Shell history:** prefix sensitive commands with a space when `HISTCONTROL=ignorespace`, or run `set +o history` for the session.

## Residual risk — stated plainly

- **A compromised repository can serve malicious source to anyone who builds from it.** No in-repo control prevents that. What you get instead is *detectability*: manifest mismatches, an unexpected capability appearing in the audit, a diff you did not review, or a non-reproducible build. The defense is external verification, not trust in the repo.
- **The manifest's own hash must come from an out-of-band channel** (a release announcement, a second mirror, a colleague) to be worth anything. A manifest committed next to the code it certifies is convenient, not authoritative.
- **Self-attestation is worthless.** A trojanized binary can print any version string, any hash, and any "self-test passed" line. Only rebuilding from independently obtained source proves anything, which is why this project's verification story is "build it yourself" and not "trust our checksum file".
- **Unsigned commits remain unsigned.** Add signing and CI build provenance (GitHub Actions attestations) as the next hardening step once maintainer keys exist; see `.github/workflows/conformance.yml` for where the gate runs.
- **There is no signing key yet**, so "verify the signature" is advice this project cannot yet satisfy. Until a key exists and its fingerprint is published independently, the only strong check available is: build from a pinned commit, compare hashes, and read the code.

## Reporting

If you find a supply-chain weakness in this repository — a path to get an unreviewed capability into a build, a gap in `tools/verify.sh`, or a reproducibility failure — open an issue describing the reproduction steps. Do not include exploit payloads; describe the mechanism.

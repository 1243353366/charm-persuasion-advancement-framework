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

## What each defense actually buys

1. **No binaries in the repository.** `.gitignore` excludes `dist/` and all compiled artifacts; `tools/verify.sh` fails if a binary (ELF, PE, Mach-O, class file, jar) ever appears in the tree. The "download the tool" habit is replaced by "compile the tool" — one command, no dependencies.
2. **Reproducible builds.** Go is built with `-trimpath -buildvcs=false`; C with fixed flags. Two builds of the same source produce identical hashes, so a user can rebuild and compare against any binary someone hands them. If the hashes differ, the binary is not this tool.
3. **Capability minimization, enforced.** The scanners read one input file (or stdin) and write to stdout. Nothing else. `tools/verify.sh` greps the four scanner sources for network, filesystem-write, and process-execution APIs and fails on any hit. A compromised commit that adds exfiltration must also visibly add `net/http`, `java.net`, `urllib`, `socket()`, or similar — and that shows up in `git diff` and in this gate.
4. **Manifest verification.** `MANIFEST.sha256` records the hash of every source and doc file. `tools/verify.sh` checks the tree against it. A one-byte change anywhere is detectable.
5. **Commit-hash pinning.** Consumers should vendor a specific commit, not track `main`: `git clone … && git checkout <sha>`. Combined with `git verify-commit` where commits are signed, silent upstream drift stops mattering.

## Verifying a checkout

```bash
tools/verify.sh        # manifest + no-binaries + capability audit
tools/reproduce.sh     # double-build determinism check
tools/build.sh         # canonical build, prints artifact hashes
```

All three are pure shell and need no toolchains beyond the ones they test for; `verify.sh` alone needs only bash, coreutils, and grep.

## Residual risk — stated plainly

- **A compromised repository can serve malicious source to anyone who builds from it.** No in-repo control prevents that. What you get instead is *detectability*: manifest mismatches, an unexpected capability appearing in the audit, a diff you did not review, or a non-reproducible build. The defense is external verification, not trust in the repo.
- **The manifest's own hash must come from an out-of-band channel** (a release announcement, a second mirror, a colleague) to be worth anything. A manifest committed next to the code it certifies is convenient, not authoritative.
- **Self-attestation is worthless.** A trojanized binary can print any version string, any hash, and any "self-test passed" line. Only rebuilding from independently obtained source proves anything, which is why this project's verification story is "build it yourself" and not "trust our checksum file".
- **Unsigned commits remain unsigned.** Add signing and CI build provenance (GitHub Actions attestations) as the next hardening step once maintainer keys exist; see `.github/workflows/conformance.yml` for where the gate runs.

## Reporting

If you find a supply-chain weakness in this repository — a path to get an unreviewed capability into a build, a gap in `tools/verify.sh`, or a reproducibility failure — open an issue describing the reproduction steps. Do not include exploit payloads; describe the mechanism.

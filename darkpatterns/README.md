# Dark Patterns & Adversarial Influence — Fast Triage Scanners

Reference implementations of **Layer 14** in Go, Java, Python, and C, built for organizations: these patterns are risks to whole organizations, not just individuals, so the scan is designed to run quickly over many reported interactions (intake queues, escalation logs, complaint triage) and produce a structured five-field record per detected tactic.

All four implementations share the same rule set and output format. The Python and C scanners are held to behavioral parity with the Go reference: identical input format, five-field records, risk thresholds, output strings, and exit codes (0 on success, 1 on input error). No dependencies, no network, single source file each — easy to drop into an existing codebase or CI pipeline.

## The five tactics and their triggers

| # | Tactic | Attack surface | Trigger condition |
|---|---|---|---|
| 1 | Incentive distortion | Decision quality | immediate payoff emphasized AND long-term cost not quantified |
| 2 | Reputation manipulation | Credibility | selective disclosure OR insinuation/framing |
| 3 | Artificial urgency | Deliberation | deadline claimed AND (source not named OR expiry consequence not named) |
| 4 | Option restriction | Perceived choice | binary framing AND alternatives not independently generated |
| 5 | Reaction engineering | Self-regulation | provocative language observed |

For every triggered tactic, the scanner prints the full five-field record: **signal, mechanism, countermeasure, false-positive risk, escalation threshold.** It then prints a risk summary and the reciprocity-audit reminder (check whether your own proposed conduct reproduces the same mechanism).

## Input format

Key=value lines, `#` for comments, `-` for stdin. Unknown keys are ignored.

```
# observed facts about the interaction
immediate_payoff_emphasized=yes
longterm_cost_quantified=no
deadline_claimed=yes
deadline_source=none
binary_framing=yes
independent_alternatives_generated=no
provocative_language=no
selective_disclosure=no
insinuation_or_framing=no
deadline_expiry_consequence=none
```

| Field | Values | Meaning |
|---|---|---|
| immediate_payoff_emphasized | yes/no | An immediate reward is being made more salient than its cost |
| longterm_cost_quantified | yes/no | The delayed cost has been stated in numbers |
| decision_criteria_documented | yes/no | Pre-established criteria exist for this decision class |
| selective_disclosure | yes/no | Only a favorable subset of the record was shared |
| insinuation_or_framing | yes/no | Unverified implication shaping observer interpretation |
| full_record_preserved | yes/no | Original records available for review |
| timeline_checked | yes/no | Claims checked against the complete timeline |
| deadline_claimed | yes/no | A time limit was asserted |
| deadline_source | named/none | What creates the deadline (review cycle, budget window…) |
| deadline_expiry_consequence | named/none | What actually happens if the deadline expires |
| binary_framing | yes/no | Decision presented as having exactly two options |
| alternatives_exist | yes/no | Other viable choices plausibly exist |
| independent_alternatives_generated | yes/no | Alternatives were generated independently of the framer |
| provocative_language | yes/no | Hostile or baiting language observed |
| initiating_event_documented | yes/no | The provocation's initiating event is on record |
| pressured_to_respond_quickly | yes/no | Response time was compressed |

## Run the Go scanner

Requires Go 1.16+.

```bash
cd go
go run darkscan.go ../sample-input.txt
# or from stdin:
go run darkscan.go - < ../sample-input.txt
```

## Run the C scanner

Requires any C11 compiler (cc, gcc, or clang). Zero dependencies, embeds anywhere a C compiler exists — appliances, air-gapped triage hosts, anywhere managed runtimes are unavailable.

```bash
cd c
cc -std=c11 -Wall -Wextra -Werror -O2 -o darkscan darkscan.c
./darkscan ../sample-input.txt
# or from stdin:
./darkscan - < ../sample-input.txt
# exit codes: 0 on success, 1 on input error (same as Go, Java, and Python)
```

## Run the Python scanner

Requires Python 3.8+ (stdlib only).

```bash
cd python
python3 darkscan.py ../sample-input.txt
# or from stdin:
python3 darkscan.py - < ../sample-input.txt
# exit codes: 0 on success, 1 on input error (same as Go and Java)
```

## Run the Java scanner

Requires JDK 11+ (single-file source launcher).

```bash
cd java
java DarkScan.java ../sample-input.txt
# or compile and run:
javac DarkScan.java && java DarkScan ../sample-input.txt
```

## Risk summary logic

- **0 tactics triggered:** no adversarial signals; log and close.
- **1–2 triggered:** apply countermeasures, document the false-positive analysis, monitor.
- **3+ triggered:** elevated — run the Layer 11 counterfactuals, apply the escalation threshold of the strongest signal, and involve the appropriate authority (manager, compliance, security) if the threshold is met.

## Continuous cross-language conformance

`.github/workflows/conformance.yml` compiles all three scanners (Go 1.22, Temurin 17, Python 3.12) on every push that touches `darkpatterns/`, then runs `darkpatterns/tests/conformance.py`: the shared corpus in `darkpatterns/tests/corpus/` is executed by every implementation whose toolchain is available (Go, Java, Python, C), and the run fails unless all three produce byte-identical output, fire the expected tactic counts, and exit identically on input errors.

Locally, with all three toolchains installed:

```bash
python3 darkpatterns/tests/conformance.py
```

## Standing rule

These scanners produce *indicators*, not verdicts. Every signal carries a false-positive explanation on its face, and the escalation thresholds are deliberately conservative. The output is a triage record for a human decision-maker, never an automated action against a person.

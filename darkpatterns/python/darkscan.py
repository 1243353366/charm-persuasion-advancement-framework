#!/usr/bin/env python3
"""Layer 14 — Dark Patterns & Adversarial Influence, fast triage scanner.

Behavioral parity with darkpatterns/go/darkscan.go and
darkpatterns/java/DarkScan.java: same input format (key=value lines,
'#' comments, '-' for stdin), same detection rules, same five-field
records, same risk thresholds, same output contract, same exit codes
(0 on success, 1 on input error). Switch implementations without
changing your workflow.

Usage:
    python3 darkscan.py <input-file>
    python3 darkscan.py -          # read stdin
"""

import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class Tactic:
    id: str
    name: str
    attack_surface: str
    trigger: str
    signal: str
    mechanism: str
    countermeasure: str
    false_positive: str
    escalation: str


TACTICS = [
    Tactic(
        id="1", name="Incentive distortion", attack_surface="decision quality",
        trigger="immediate_payoff_emphasized=yes & longterm_cost_quantified=no",
        signal="An immediate payoff is being made more salient than a long-term cost",
        mechanism="Salience and reward bias: immediate rewards loom larger than delayed, diffuse costs",
        countermeasure="Evaluate the decision against pre-established criteria rather than the emotional intensity of the moment",
        false_positive="A genuine short-term opportunity with a real, documented payoff",
        escalation="Repeated steering toward decisions that bypass documented criteria; involve the accountable decision owner",
    ),
    Tactic(
        id="2", name="Reputation manipulation", attack_surface="credibility",
        trigger="selective_disclosure=yes | insinuation_or_framing=yes",
        signal="Selective disclosure, insinuation, or framing is shaping how observers interpret an event",
        mechanism="Interpretation is steered by controlling which subset of the record is available to the audience",
        countermeasure="Preserve original records, separate fact from inference, check claims against the complete timeline",
        false_positive="Legitimate privacy, discretion, or a partially complete record shared in good faith",
        escalation="A documented pattern of selective framing affecting personnel decisions; involve HR or compliance",
    ),
    Tactic(
        id="3", name="Artificial urgency", attack_surface="deliberation",
        trigger="deadline_claimed=yes & deadline_source=none | deadline_claimed=yes & deadline_expiry_consequence=none",
        signal="A deadline is asserted without a named source or a stated expiry consequence",
        mechanism="Compressed evaluation time suppresses independent review and comparison shopping",
        countermeasure="Verify the deadline, ask what actually changes when it expires, apply a predetermined decision rule",
        false_positive="A real deadline the speaker simply failed to explain; the fix is asking, not refusing",
        escalation="Manufactured urgency used to extract commitments; involve the decision owner and document the instance",
    ),
    Tactic(
        id="4", name="Option restriction", attack_surface="perceived choice",
        trigger="binary_framing=yes & independent_alternatives_generated=no",
        signal="A decision is framed as having exactly two options and no alternatives were generated independently",
        mechanism="The choice set is controlled by the framer; whatever the framer omits never gets evaluated",
        countermeasure="Generate alternatives independently; distinguish genuine constraints from asserted ones",
        false_positive="A decision that genuinely has two options; test by attempting to name a third",
        escalation="Repeated binary framing that funnels decisions to one beneficiary; involve the decision owner",
    ),
    Tactic(
        id="5", name="Reaction engineering", attack_surface="self-regulation",
        trigger="provocative_language=yes",
        signal="Provocative language is pushing toward an impulsive response that distracts from the original issue",
        mechanism="Emotional hijack: the provoked party's reaction, not the initiator's conduct, becomes the subject",
        countermeasure="Delay consequential reactions, document the initiating event, refuse to let hostility determine the next move",
        false_positive="Plain, legitimate criticism that happened to sting; the test is whether it demands a fast public response",
        escalation="A documented provocation pattern aimed at eliciting damaging reactions; involve a manager or HR",
    ),
]


def match_group(cond: str, fields: dict) -> bool:
    """One '&'-joined clause: every field=value must hold."""
    for c in cond.split("&"):
        key, sep, value = c.partition("=")
        if not sep:
            return False
        if fields.get(key.strip()) != value.strip():
            return False
    return True


def match(trigger: str, fields: dict) -> bool:
    """'|'-separated OR of '&'-joined AND groups."""
    return any(match_group(g, fields) for g in trigger.split("|"))


def load_fields(path: str) -> dict:
    fields = {}
    stream = sys.stdin if path == "-" else open(path, encoding="utf-8")
    try:
        for line in stream:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, sep, value = line.partition("=")
            if sep and key.strip():
                fields[key.strip()] = value.strip()
    finally:
        if stream is not sys.stdin:
            stream.close()
    return fields


def main(argv=None) -> int:
    args = sys.argv[1:] if argv is None else argv
    path = args[0] if args else "-"

    try:
        fields = load_fields(path)
    except OSError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print("DARK PATTERNS & ADVERSARIAL INFLUENCE SCAN (Layer 14)")
    print("=" * 64)

    matched = 0
    for t in TACTICS:
        if not match(t.trigger, fields):
            continue
        matched += 1
        print()
        print(f"[{t.id}] {t.name}  (attack surface: {t.attack_surface})")
        print("  Signal:          " + t.signal)
        print("  Mechanism:       " + t.mechanism)
        print("  Countermeasure:  " + t.countermeasure)
        print("  False-positive:  " + t.false_positive)
        print("  Escalation:      " + t.escalation)

    print()
    print("-" * 64)
    if matched == 0:
        print("Risk summary: 0 tactics triggered — no adversarial signals; log and close.")
    elif matched <= 2:
        print(f"Risk summary: {matched} tactic(s) triggered — apply countermeasures, "
              "document the false-positive analysis, monitor.")
    else:
        print(f"Risk summary: {matched} tactics triggered — ELEVATED. Run the Layer 11 "
              "counterfactuals, apply the strongest signal's escalation threshold, and "
              "involve the appropriate authority if met.")
    print("Reciprocity audit: for every tactic detected, check whether your own proposed "
          "conduct reproduces the same mechanism.")
    print("Standing rule: this output is a triage record for a human decision-maker, "
          "never an automated action against a person.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

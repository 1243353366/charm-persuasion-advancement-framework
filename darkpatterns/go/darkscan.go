package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

type tactic struct {
	ID, Name, AttackSurface, Trigger, Signal, Mechanism, Countermeasure, FalsePositive, Escalation string
}

var tactics = []tactic{
	{
		ID: "1", Name: "Incentive distortion", AttackSurface: "decision quality",
		Trigger:            "immediate_payoff_emphasized=yes & longterm_cost_quantified=no",
		Signal:             "An immediate payoff is being made more salient than a long-term cost",
		Mechanism:          "Salience and reward bias: immediate rewards loom larger than delayed, diffuse costs",
		Countermeasure:     "Evaluate the decision against pre-established criteria rather than the emotional intensity of the moment",
		FalsePositive:      "A genuine short-term opportunity with a real, documented payoff",
		Escalation:        "Repeated steering toward decisions that bypass documented criteria; involve the accountable decision owner",
	},
	{
		ID: "2", Name: "Reputation manipulation", AttackSurface: "credibility",
		Trigger:            "selective_disclosure=yes | insinuation_or_framing=yes",
		Signal:             "Selective disclosure, insinuation, or framing is shaping how observers interpret an event",
		Mechanism:          "Interpretation is steered by controlling which subset of the record is available to the audience",
		Countermeasure:     "Preserve original records, separate fact from inference, check claims against the complete timeline",
		FalsePositive:      "Legitimate privacy, discretion, or a partially complete record shared in good faith",
		Escalation:        "A documented pattern of selective framing affecting personnel decisions; involve HR or compliance",
	},
	{
		ID: "3", Name: "Artificial urgency", AttackSurface: "deliberation",
		Trigger:            "deadline_claimed=yes & deadline_source=none | deadline_claimed=yes & deadline_expiry_consequence=none",
		Signal:             "A deadline is asserted without a named source or a stated expiry consequence",
		Mechanism:          "Compressed evaluation time suppresses independent review and comparison shopping",
		Countermeasure:     "Verify the deadline, ask what actually changes when it expires, apply a predetermined decision rule",
		FalsePositive:      "A real deadline the speaker simply failed to explain; the fix is asking, not refusing",
		Escalation:        "Manufactured urgency used to extract commitments; involve the decision owner and document the instance",
	},
	{
		ID: "4", Name: "Option restriction", AttackSurface: "perceived choice",
		Trigger:            "binary_framing=yes & independent_alternatives_generated=no",
		Signal:             "A decision is framed as having exactly two options and no alternatives were generated independently",
		Mechanism:          "The choice set is controlled by the framer; whatever the framer omits never gets evaluated",
		Countermeasure:     "Generate alternatives independently; distinguish genuine constraints from asserted ones",
		FalsePositive:      "A decision that genuinely has two options; test by attempting to name a third",
		Escalation:        "Repeated binary framing that funnels decisions to one beneficiary; involve the decision owner",
	},
	{
		ID: "5", Name: "Reaction engineering", AttackSurface: "self-regulation",
		Trigger:            "provocative_language=yes",
		Signal:             "Provocative language is pushing toward an impulsive response that distracts from the original issue",
		Mechanism:          "Emotional hijack: the provoked party's reaction, not the initiator's conduct, becomes the subject",
		Countermeasure:     "Delay consequential reactions, document the initiating event, refuse to let hostility determine the next move",
		FalsePositive:      "Plain, legitimate criticism that happened to sting; the test is whether it demands a fast public response",
		Escalation:        "A documented provocation pattern aimed at eliciting damaging reactions; involve a manager or HR",
	},
}

func matchGroup(cond string, f map[string]string) bool {
	for _, c := range strings.Split(cond, "&") {
		parts := strings.SplitN(strings.TrimSpace(c), "=", 2)
		if len(parts) != 2 {
			return false
		}
		if f[strings.TrimSpace(parts[0])] != strings.TrimSpace(parts[1]) {
			return false
		}
	}
	return true
}

func match(trigger string, f map[string]string) bool {
	for _, g := range strings.Split(trigger, "|") {
		if matchGroup(g, f) {
			return true
		}
	}
	return false
}

func loadFields(path string) (map[string]string, error) {
	f := map[string]string{}
	var s *bufio.Scanner
	if path == "-" {
		s = bufio.NewScanner(os.Stdin)
	} else {
		file, err := os.Open(path)
		if err != nil {
			return nil, err
		}
		defer file.Close()
		s = bufio.NewScanner(file)
	}
	for s.Scan() {
		line := strings.TrimSpace(s.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if i := strings.Index(line, "="); i > 0 {
			f[strings.TrimSpace(line[:i])] = strings.TrimSpace(line[i+1:])
		}
	}
	return f, s.Err()
}

func main() {
	path := "-"
	if len(os.Args) > 1 {
		path = os.Args[1]
	}
	f, err := loadFields(path)
	if err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
	fmt.Println("DARK PATTERNS & ADVERSARIAL INFLUENCE SCAN (Layer 14)")
	fmt.Println(strings.Repeat("=", 64))
	matched := 0
	for _, t := range tactics {
		if match(t.Trigger, f) {
			matched++
			fmt.Printf("\n[%s] %s  (attack surface: %s)\n", t.ID, t.Name, t.AttackSurface)
			fmt.Println("  Signal:          " + t.Signal)
			fmt.Println("  Mechanism:       " + t.Mechanism)
			fmt.Println("  Countermeasure:  " + t.Countermeasure)
			fmt.Println("  False-positive:  " + t.FalsePositive)
			fmt.Println("  Escalation:      " + t.Escalation)
		}
	}
	fmt.Println()
	fmt.Println(strings.Repeat("-", 64))
	switch {
	case matched == 0:
		fmt.Println("Risk summary: 0 tactics triggered — no adversarial signals; log and close.")
	case matched <= 2:
		fmt.Printf("Risk summary: %d tactic(s) triggered — apply countermeasures, document the false-positive analysis, monitor.\n", matched)
	default:
		fmt.Printf("Risk summary: %d tactics triggered — ELEVATED. Run the Layer 11 counterfactuals, apply the strongest signal's escalation threshold, and involve the appropriate authority if met.\n", matched)
	}
	fmt.Println("Reciprocity audit: for every tactic detected, check whether your own proposed conduct reproduces the same mechanism.")
	fmt.Println("Standing rule: this output is a triage record for a human decision-maker, never an automated action against a person.")
}

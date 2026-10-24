import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Layer 14 — Dark Patterns & Adversarial Influence, fast triage scanner.
 * Java 11+ single-file source: java DarkScan.java <input-file|->
 */
public class DarkScan {

    static class Tactic {
        final String id, name, attackSurface, trigger, signal, mechanism, countermeasure, falsePositive, escalation;

        Tactic(String id, String name, String attackSurface, String trigger, String signal,
               String mechanism, String countermeasure, String falsePositive, String escalation) {
            this.id = id; this.name = name; this.attackSurface = attackSurface; this.trigger = trigger;
            this.signal = signal; this.mechanism = mechanism; this.countermeasure = countermeasure;
            this.falsePositive = falsePositive; this.escalation = escalation;
        }
    }

    static final List<Tactic> TACTICS = List.of(
        new Tactic("1", "Incentive distortion", "decision quality",
            "immediate_payoff_emphasized=yes & longterm_cost_quantified=no",
            "An immediate payoff is being made more salient than a long-term cost",
            "Salience and reward bias: immediate rewards loom larger than delayed, diffuse costs",
            "Evaluate the decision against pre-established criteria rather than the emotional intensity of the moment",
            "A genuine short-term opportunity with a real, documented payoff",
            "Repeated steering toward decisions that bypass documented criteria; involve the accountable decision owner"),
        new Tactic("2", "Reputation manipulation", "credibility",
            "selective_disclosure=yes | insinuation_or_framing=yes",
            "Selective disclosure, insinuation, or framing is shaping how observers interpret an event",
            "Interpretation is steered by controlling which subset of the record is available to the audience",
            "Preserve original records, separate fact from inference, check claims against the complete timeline",
            "Legitimate privacy, discretion, or a partially complete record shared in good faith",
            "A documented pattern of selective framing affecting personnel decisions; involve HR or compliance"),
        new Tactic("3", "Artificial urgency", "deliberation",
            "deadline_claimed=yes & deadline_source=none | deadline_claimed=yes & deadline_expiry_consequence=none",
            "A deadline is asserted without a named source or a stated expiry consequence",
            "Compressed evaluation time suppresses independent review and comparison shopping",
            "Verify the deadline, ask what actually changes when it expires, apply a predetermined decision rule",
            "A real deadline the speaker simply failed to explain; the fix is asking, not refusing",
            "Manufactured urgency used to extract commitments; involve the decision owner and document the instance"),
        new Tactic("4", "Option restriction", "perceived choice",
            "binary_framing=yes & independent_alternatives_generated=no",
            "A decision is framed as having exactly two options and no alternatives were generated independently",
            "The choice set is controlled by the framer; whatever the framer omits never gets evaluated",
            "Generate alternatives independently; distinguish genuine constraints from asserted ones",
            "A decision that genuinely has two options; test by attempting to name a third",
            "Repeated binary framing that funnels decisions to one beneficiary; involve the decision owner"),
        new Tactic("5", "Reaction engineering", "self-regulation",
            "provocative_language=yes",
            "Provocative language is pushing toward an impulsive response that distracts from the original issue",
            "Emotional hijack: the provoked party's reaction, not the initiator's conduct, becomes the subject",
            "Delay consequential reactions, document the initiating event, refuse to let hostility determine the next move",
            "Plain, legitimate criticism that happened to sting; the test is whether it demands a fast public response",
            "A documented provocation pattern aimed at eliciting damaging reactions; involve a manager or HR")
    );

    static Map<String, String> loadFields(String path) throws IOException {
        Map<String, String> f = new HashMap<>();
        List<String> lines = new ArrayList<>();
        if ("-".equals(path)) {
            try (BufferedReader r = new BufferedReader(new InputStreamReader(System.in))) {
                String l;
                while ((l = r.readLine()) != null) lines.add(l);
            }
        } else {
            lines = Files.readAllLines(Paths.get(path));
        }
        for (String line : lines) {
            String s = line.trim();
            if (s.isEmpty() || s.startsWith("#")) continue;
            int i = s.indexOf('=');
            if (i > 0) f.put(s.substring(0, i).trim(), s.substring(i + 1).trim());
        }
        return f;
    }

    static boolean matchGroup(String cond, Map<String, String> f) {
        for (String c : cond.split("&")) {
            int i = c.indexOf('=');
            if (i < 0) return false;
            if (!c.substring(i + 1).trim().equals(f.get(c.substring(0, i).trim()))) return false;
        }
        return true;
    }

    static boolean match(String trigger, Map<String, String> f) {
        for (String g : trigger.split("\\|")) {
            if (matchGroup(g, f)) return true;
        }
        return false;
    }

    static void line(String s) { System.out.println(s); }

    public static void main(String[] args) throws IOException {
        String path = args.length > 0 ? args[0] : "-";
        Map<String, String> f = loadFields(path);

        line("DARK PATTERNS & ADVERSARIAL INFLUENCE SCAN (Layer 14)");
        line("================================================================");
        int matched = 0;
        for (Tactic t : TACTICS) {
            if (!match(t.trigger, f)) continue;
            matched++;
            line("");
            line("[" + t.id + "] " + t.name + "  (attack surface: " + t.attackSurface + ")");
            line("  Signal:          " + t.signal);
            line("  Mechanism:       " + t.mechanism);
            line("  Countermeasure:  " + t.countermeasure);
            line("  False-positive:  " + t.falsePositive);
            line("  Escalation:      " + t.escalation);
        }
        line("");
        line("----------------------------------------------------------------");
        if (matched == 0) {
            line("Risk summary: 0 tactics triggered - no adversarial signals; log and close.");
        } else if (matched <= 2) {
            line("Risk summary: " + matched + " tactic(s) triggered - apply countermeasures, document the false-positive analysis, monitor.");
        } else {
            line("Risk summary: " + matched + " tactics triggered - ELEVATED. Run the Layer 11 counterfactuals, apply the strongest signal's escalation threshold, and involve the appropriate authority if met.");
        }
        line("Reciprocity audit: for every tactic detected, check whether your own proposed conduct reproduces the same mechanism.");
        line("Standing rule: this output is a triage record for a human decision-maker, never an automated action against a person.");
    }
}

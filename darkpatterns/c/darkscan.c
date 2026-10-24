/*
 * Layer 14 — Dark Patterns & Adversarial Influence, fast triage scanner.
 *
 * Behavioral parity with darkpatterns/go/darkscan.go, darkpatterns/java/DarkScan.java,
 * and darkpatterns/python/darkscan.py: same input format (key=value lines,
 * '#' comments, "-" for stdin), same detection rules, same five-field records,
 * same risk thresholds, same output contract, same exit codes
 * (0 on success, 1 on input error).
 *
 * Build:   cc -std=c11 -Wall -Wextra -O2 -o darkscan darkscan.c
 * Usage:   ./darkscan <input-file>    |    ./darkscan -   (stdin)
 *
 * C11, standard library only. Compiles anywhere a C compiler exists —
 * built for embedding in organizational infrastructure where runtimes
 * for managed languages are not available.
 */

#define _POSIX_C_SOURCE 200809L /* strtok_r */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_FIELDS 64
#define MAX_LINE 4096

typedef struct {
    char key[128];
    char value[64];
} Field;

typedef struct {
    const char *id;
    const char *name;
    const char *attack_surface;
    const char *trigger;
    const char *signal;
    const char *mechanism;
    const char *countermeasure;
    const char *false_positive;
    const char *escalation;
} Tactic;

static const Tactic TACTICS[] = {
    {
        "1", "Incentive distortion", "decision quality",
        "immediate_payoff_emphasized=yes & longterm_cost_quantified=no",
        "An immediate payoff is being made more salient than a long-term cost",
        "Salience and reward bias: immediate rewards loom larger than delayed, diffuse costs",
        "Evaluate the decision against pre-established criteria rather than the emotional intensity of the moment",
        "A genuine short-term opportunity with a real, documented payoff",
        "Repeated steering toward decisions that bypass documented criteria; involve the accountable decision owner",
    },
    {
        "2", "Reputation manipulation", "credibility",
        "selective_disclosure=yes | insinuation_or_framing=yes",
        "Selective disclosure, insinuation, or framing is shaping how observers interpret an event",
        "Interpretation is steered by controlling which subset of the record is available to the audience",
        "Preserve original records, separate fact from inference, check claims against the complete timeline",
        "Legitimate privacy, discretion, or a partially complete record shared in good faith",
        "A documented pattern of selective framing affecting personnel decisions; involve HR or compliance",
    },
    {
        "3", "Artificial urgency", "deliberation",
        "deadline_claimed=yes & deadline_source=none | deadline_claimed=yes & deadline_expiry_consequence=none",
        "A deadline is asserted without a named source or a stated expiry consequence",
        "Compressed evaluation time suppresses independent review and comparison shopping",
        "Verify the deadline, ask what actually changes when it expires, apply a predetermined decision rule",
        "A real deadline the speaker simply failed to explain; the fix is asking, not refusing",
        "Manufactured urgency used to extract commitments; involve the decision owner and document the instance",
    },
    {
        "4", "Option restriction", "perceived choice",
        "binary_framing=yes & independent_alternatives_generated=no",
        "A decision is framed as having exactly two options and no alternatives were generated independently",
        "The choice set is controlled by the framer; whatever the framer omits never gets evaluated",
        "Generate alternatives independently; distinguish genuine constraints from asserted ones",
        "A decision that genuinely has two options; test by attempting to name a third",
        "Repeated binary framing that funnels decisions to one beneficiary; involve the decision owner",
    },
    {
        "5", "Reaction engineering", "self-regulation",
        "provocative_language=yes",
        "Provocative language is pushing toward an impulsive response that distracts from the original issue",
        "Emotional hijack: the provoked party's reaction, not the initiator's conduct, becomes the subject",
        "Delay consequential reactions, document the initiating event, refuse to let hostility determine the next move",
        "Plain, legitimate criticism that happened to sting; the test is whether it demands a fast public response",
        "A documented provocation pattern aimed at eliciting damaging reactions; involve a manager or HR",
    },
};

static const size_t N_TACTICS = sizeof(TACTICS) / sizeof(TACTICS[0]);

static char *trim(char *s)
{
    while (*s == ' ' || *s == '\t') s++;
    char *end = s + strlen(s);
    while (end > s && (end[-1] == ' ' || end[-1] == '\t' || end[-1] == '\r' || end[-1] == '\n'))
        *(--end) = '\0';
    return s;
}

static const char *field_get(const Field *fields, size_t n, const char *key)
{
    for (size_t i = 0; i < n; i++) {
        if (strcmp(fields[i].key, key) == 0)
            return fields[i].value;
    }
    return NULL;
}

/* One '&'-joined clause: every field=value must hold. cond is not modified. */
static int match_group(const char *cond, const Field *fields, size_t n)
{
    char buf[512];
    snprintf(buf, sizeof buf, "%s", cond);

    char *save = NULL;
    for (char *tok = strtok_r(buf, "&", &save); tok; tok = strtok_r(NULL, "&", &save)) {
        char *eq = strchr(tok, '=');
        if (!eq) return 0;
        *eq = '\0';
        const char *key = trim(tok);
        const char *value = trim(eq + 1);
        const char *have = field_get(fields, n, key);
        if (!have || strcmp(have, value) != 0) return 0;
    }
    return 1;
}

/* '|'-separated OR of '&'-joined AND groups. trigger is not modified. */
static int match(const char *trigger, const Field *fields, size_t n)
{
    char buf[512];
    snprintf(buf, sizeof buf, "%s", trigger);

    char *save = NULL;
    for (char *tok = strtok_r(buf, "|", &save); tok; tok = strtok_r(NULL, "|", &save)) {
        if (match_group(tok, fields, n)) return 1;
    }
    return 0;
}

static size_t load_fields(FILE *in, Field *fields)
{
    char line[MAX_LINE];
    size_t n = 0;
    while (fgets(line, sizeof line, in)) {
        char *s = trim(line);
        if (*s == '\0' || *s == '#') continue;
        char *eq = strchr(s, '=');
        if (!eq || eq == s || n >= MAX_FIELDS) continue;
        *eq = '\0';
        char *key = trim(s);
        char *value = trim(eq + 1);
        snprintf(fields[n].key, sizeof fields[n].key, "%s", key);
        snprintf(fields[n].value, sizeof fields[n].value, "%s", value);
        n++;
    }
    return n;
}

int main(int argc, char **argv)
{
    const char *path = argc > 1 ? argv[1] : "-";
    FILE *in = strcmp(path, "-") == 0 ? stdin : fopen(path, "r");
    if (!in) {
        fprintf(stderr, "error: cannot open %s\n", path);
        return 1;
    }

    Field fields[MAX_FIELDS];
    size_t n = load_fields(in, fields);
    if (in != stdin) fclose(in);

    printf("DARK PATTERNS & ADVERSARIAL INFLUENCE SCAN (Layer 14)\n");
    for (int i = 0; i < 64; i++) putchar('=');
    putchar('\n');

    int matched = 0;
    for (size_t t = 0; t < N_TACTICS; t++) {
        const Tactic *tc = &TACTICS[t];
        if (!match(tc->trigger, fields, n)) continue;
        matched++;
        printf("\n[%s] %s  (attack surface: %s)\n", tc->id, tc->name, tc->attack_surface);
        printf("  Signal:          %s\n", tc->signal);
        printf("  Mechanism:       %s\n", tc->mechanism);
        printf("  Countermeasure:  %s\n", tc->countermeasure);
        printf("  False-positive:  %s\n", tc->false_positive);
        printf("  Escalation:      %s\n", tc->escalation);
    }

    printf("\n");
    for (int i = 0; i < 64; i++) putchar('-');
    putchar('\n');
    if (matched == 0) {
        printf("Risk summary: 0 tactics triggered — no adversarial signals; log and close.\n");
    } else if (matched <= 2) {
        printf("Risk summary: %d tactic(s) triggered — apply countermeasures, "
               "document the false-positive analysis, monitor.\n", matched);
    } else {
        printf("Risk summary: %d tactics triggered — ELEVATED. Run the Layer 11 "
               "counterfactuals, apply the strongest signal's escalation threshold, and "
               "involve the appropriate authority if met.\n", matched);
    }
    printf("Reciprocity audit: for every tactic detected, check whether your own proposed "
           "conduct reproduces the same mechanism.\n");
    printf("Standing rule: this output is a triage record for a human decision-maker, "
           "never an automated action against a person.\n");
    return 0;
}

# Adherence-query reference

`adherence.pl` predicates and ad-hoc query patterns for the `measure-entailment` skill.

## adherence.pl predicates

Bundled at `${CLAUDE_SKILL_DIR}/prolog/adherence.pl`.

### Structural (resource-vs-resource)

| Predicate | What it does |
|-----------|-------------|
| `all_resources(-Rs)` | List all distinct resource IDs in the facts file |
| `total_claims(+R, -N)` | Count total claims for resource R |
| `shared_claims(+R1, +R2, -Claims)` | Claims present in both R1 and R2 |
| `gap_claims(+Prime, +Other, -Claims)` | Claims in Prime missing from Other |
| `extension_claims(+Prime, +Other, -Claims)` | Claims in Other not in Prime |
| `find_contradictions(-Pairs)` | Find pairs of conflicting claims across resources |
| `adherence_score(+Other, +Prime, -Score)` | 0.0–1.0 prime-relative adherence |
| `jaccard_score(+R1, +R2, -Score)` | 0.0–1.0 symmetric Jaccard similarity |
| `adherence_report(+Prime)` | Print full prime-relative report to stdout |
| `symmetric_report` | Print pairwise symmetric report to stdout |
| `universal_claim(-Claim)` | Claims present across all resources |

### Label-aware (consume `thoughts/hypothesis.pl`)

These predicates require `hypothesis.pl` to be `consult/1`'ed into the swipl session alongside `adherence_facts.pl`. They guard themselves with `hypothesis_loaded/0` and silently return `[]` (or print a skip message) when no hypothesis is loaded.

| Predicate | What it does |
|-----------|-------------|
| `hypothesis_loaded` | Semidet guard — succeeds when hypothesis predicates are visible |
| `counterfactual_violations(+Impl, -Vs)` | Pattern 3 detector — counterfactual claim whose forbidden fact is still in Impl |
| `counterfactual_honored(+Impl, -Hs)` | Counterfactual claim whose forbidden fact is correctly absent |
| `prescriptive_unfulfilled(+Impl, -Us)` | Prescriptive positive premise missing from Impl |
| `prescriptive_fulfilled(+Impl, -Fs)` | Prescriptive positive premise present in Impl |
| `prescriptive_negation_violations(+Impl, -Vs)` | Prescriptive negated premise still asserted in Impl |
| `descriptive_drift(+Impl, +Existing, -Lost)` | Facts in existing-world that no longer appear in Impl |
| `label_aware_report(+Impl)` | Print the Headline Verdicts block to stdout |
| `label_aware_facts_out(+Impl, +Stream)` | Emit machine-readable result/N facts mirroring the report |

## Ad-hoc query patterns

```prolog
% What does only resource A assert (not B or C)?
findall(C, (asserts(a, C), \+ asserts(b, C), \+ asserts(c, C)), Unique)

% How many claims does each resource make?
forall(
  (all_resources(Rs), member(R, Rs)),
  (total_claims(R, N), format('~w: ~w claims~n', [R, N]))
)

% Find all values for a given predicate across resources
findall(R-V, asserts(R, has_property(key_name, V)), Pairs)
```

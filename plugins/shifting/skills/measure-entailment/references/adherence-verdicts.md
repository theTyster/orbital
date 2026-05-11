# Adherence verdict semantics

The Headline Verdicts section of `thoughts/adherence_report.md` (pipeline-terminal mode only) renders four named verdicts, each backed by a label-aware predicate from `references/adherence-queries.md`.

## Pattern 3 — counterfactual violations

For each `result(counterfactual_violation, ImplResource, ClaimId, Fact, Provenance)`:

- **{ClaimId}** — *"{natural-language claim from `claim/2`}"*
  - Forbidden fact: `{Fact}`
  - Provenance: `{absent | contradicts}`
  - Still asserted in: `{ImplResource}` — locate the source line(s) that re-introduce it.

A counterfactual claim declared a fact had to flip; the implementation still asserts it. A non-zero count here often invalidates an otherwise high adherence score, which is why the verdict appears above the structural numbers.

## Prescriptive unfulfilled

For each `result(prescriptive_unfulfilled, ImplResource, ClaimId, Fact)`:

- **{ClaimId}** — *"{natural-language claim}"*
  - Required fact: `{Fact}`
  - Missing from: `{ImplResource}`

## Prescriptive negation violations

For each `result(prescriptive_negation_violation, ImplResource, ClaimId, Fact, Provenance)`:

- **{ClaimId}** — *"{natural-language claim}"*
  - Required-to-be-absent fact: `{Fact}`
  - Provenance: `{absent | contradicts}`
  - Still asserted in: `{ImplResource}`

## Descriptive drift

If `existing-world.pl` was supplied as a resource, list the gap from `descriptive_drift(impl, existing, Lost)`. Otherwise note "skipped — no existing-world resource."

## Hand-off to human review

`thoughts/adherence_report.md` is a `reviewed_by(_, human_review)` artifact in the target KB — the terminal pipeline output a human reads to decide whether the implementation entails the original proposition. The Headline Verdicts section is structured exactly so a reviewer sees, in order:

1. **Pattern 3 violations** — named obligation breaches; surface above the structural numbers.
2. **Prescriptive unfulfilled / negation violations** — required facts missing or required-absent facts still present.
3. **Contradictions** — direct disagreements between resources detected by `find_contradictions/1`.
4. **Descriptive drift** — only when existing-world.pl is loaded as a resource.

A reviewer who reads only the top of the report should still know whether the implementation honored its formal obligations. If a run finds zero violations across all four categories, say so explicitly — the absence of bad news is itself a verdict.

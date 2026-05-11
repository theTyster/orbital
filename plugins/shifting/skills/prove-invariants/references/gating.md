# Gating — route each property by ontology label

Not every property earns a Lean proof. The Lean kernel earns its keep on claims requiring induction, infinite-domain quantification, or non-trivial rewriting; trivially-decidable properties (membership in a small concrete enum, KB readouts, vacuous absences) cost build time without producing information the Prolog model layer didn't already carry.

Route each `formal_property/3` by its ontology label and negation provenance:

| Ontology label | Provenance | Action |
|---|---|---|
| `counterfactual` | `contradicts` | **Run Lean.** Necessity lemma proves the CF is load-bearing — tactical proof using a CF-augmented inductive predicate, not `decide`. |
| `counterfactual` | `absent` | **Skip Lean.** Emit a `cwa_check` artifact in `lean_proof_results.pl`: confirm Prolog absence, record fact id. No theorem. |
| `prescriptive` | (any) | **Run Lean iff structurally rich** — induction, quantification over an open domain, cross-predicate reasoning. **Skip if** the property reduces to literal-list membership over an inductive enum (then the constructor name *is* the proof; no theorem needed). |
| `descriptive` | (any) | **Skip Lean.** Descriptive claims are KB readouts; the Prolog model already entails them. |

The conservative starting heuristic: skip Lean iff *all* `formal_property` premises are `negation_provenance(absent)` AND the property body is finite-list membership. Anything else still runs Lean. Bias toward false-run during initial rollout — false-skip means losing a real proof; false-run means burning build time on a tautology. The cost is asymmetric.

After the structural-translation rule landed, more properties become "structurally rich" and the gate naturally tightens. The hard rule on forbidden tactics provides a sharp signal in either direction: if a theorem can *only* close via `decide` / `native_decide` / `generalize`, that is not a Lean-tractable property at all — it is a property whose encoding upstream is wrong, and the right response is to escalate to `model-obligations` for re-encoding rather than to gate it through to Lean. The gate and the hard rule together close the loop: Lean either runs on a structurally-rich theorem and produces real evidence, or doesn't run because the property is trivially decidable, or halts because the encoding is broken. No middle ground where Lean fakes a proof.

## `cwa_check` records replace skipped Lean proofs

For each property gated out of Lean, emit a `cwa_check/3` record in `lean_proof_results.pl` instead of `theorem_verdict/2`:

```prolog
% cwa_check(PropId, AbsentFactId, verified | violated).
% verified  → swipl-confirmed: \+ Fact succeeds in target-world.
% violated  → swipl-confirmed: Fact still derivable; loopback to model-obligations.
cwa_check(p_no_cli_to_logging, depends_on(cli_tool, logging), verified).

% lean_skipped/2 — reason annotation co-emitted with each cwa_check.
lean_skipped(p_no_cli_to_logging, trivially_decidable_over_kb_listing).

% provenance_annotation/3 still required — same chain as a Lean theorem so
% downstream instantiate-properties keeps its ontology label intact.
provenance_annotation(p_no_cli_to_logging, depends_on(cli_tool, logging), absent).
```

Run the absence check by direct `swipl` query against `target-world.pl`:

```bash
swipl -g "consult('thoughts/target-world.pl'),
          ( \+ depends_on(cli_tool, logging) -> Verdict = verified ; Verdict = violated ),
          format('~w', [Verdict]), halt." 2>/dev/null
```

The TDD stage continues to receive every property — `instantiate-properties` emits the same number of tests with the same ontology labels. Only the *proof shape* differs: `cwa_check`-backed projections carry a `proof_strategy: prolog-cwa-check` annotation in their test comment block.

## Skip rationale

Skipping a Lean proof is recorded, not silent. Every `cwa_check` carries an explicit `lean_skipped(PropId, Reason)` fact. Reasons:

- `trivially_decidable_over_kb_listing` — the property reduces to membership in an inductive enum and the constructor name *is* the proof.
- `descriptive_kb_readout` — the property restates an existing-world fact the Prolog model already entails.
- `cwa_absence_verified_directly` — the absence is the property; Prolog's `\+` confirmation is the entire content.

A reviewer reading `lean_proof_results.pl` should be able to tell at a glance which properties earned a kernel guarantee and which earned a Prolog-CWA confirmation, without having to cross-reference the Lean source.

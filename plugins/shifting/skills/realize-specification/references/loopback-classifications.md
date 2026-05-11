# Stage 4 — loopback classification

Sub-agent brief for `Agent(Explore)` when a test cannot be made green after two implementation attempts:

> This test cannot be made to pass after two implementation attempts. Read `{briefing_path}` and the digests `{2c_digest_path}`, `{2e_iter1_digest_path}`, `{2e_iter2_digest_path}`. Classify the failure as one of:
>
> - **Test is wrong** — the test's projection from the proof is incorrect (wrong assertion, wrong fixture, wrong shape)
> - **Property is wrong** — the proof is internally valid but models something different from the real system
> - **Tests conflict** — satisfying this test would violate a different proven property
> - **Missing context** — the proof depends on a precondition not expressed in any test
> - **Fragile counterfactual (CWA-absent)** *(only when `test_category(projection)` AND cited claim has `claim_label(_, counterfactual)` AND `negation_provenance(_, absent)`)* — the proof's negation depends on closed-world absence; the absent premise may be the cause of failure. The KB's completeness is suspect.
> - **Counterfactual list inaccurate** — the enumerated counterfactual claims in `hypothesis.pl` do not match reality: either a named fact cannot be cleanly removed because another proven property depends on it, or removing the fact is not enough to satisfy the downstream invariant.
> - **Behavioral test has no upstream property** — the failing test is `test_category(behavioral_claim)`. There is no proof to revise, no hypothesis to re-run. Recommendation: do NOT loop back; surface to the user.
>
> Do not edit anything. Return the classification plus a recommendation of which pipeline stage to revisit (`decompose-proposition`, `prove-invariants` or `model-obligations`, or `instantiate-properties`).

## Loopback routing (recommendations only — the human chooses)

- Persistent failure on a `projection` test whose cited claim has `claim_label(_, counterfactual)` and `negation_provenance(_, absent)` → recommend `decompose-proposition` (the fragile CWA premise may be the cause).
- Persistent failure on any other `projection` test → recommend revisiting one of the prove skills (`prove-invariants` or `model-obligations`).
- Persistent failure on a `behavioral_claim` test → recommend NO formal-pipeline revisit. Surface to the user.

For `test_category(behavioral_claim)` classifications, the `implementation_blocked.md` output must explicitly say "no upstream pipeline stage revises this claim".

The orchestrator writes the classification and recommended pipeline stage to `thoughts/implementation_blocked.md`, halts, and leaves the offending test unskipped with its failure intact. **The skill does not auto-restart any upstream stage** — the human reads the blocked report and decides what to re-run.

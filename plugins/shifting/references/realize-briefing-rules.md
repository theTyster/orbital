# Realize-Specification Briefing Rule Blocks

Canonical rule blocks copied verbatim into briefings emitted by the `realize-test-briefer` agent. Keeping them here, rather than inline in `SKILL.md` or in the agent prompt, ensures every briefing the orchestrator hands to an implementation sub-agent carries the same constraints.

When the briefer assembles a briefing, it copies the matching block under a `## Rules` header at the bottom of the briefing file — verbatim, without paraphrase.

---

## Addition rules block

Used for `test_category(projection)` tests whose cited claim has `claim_label(_, descriptive)` or `claim_label(_, prescriptive)`.

```markdown
## Rules

- This test samples one point in a proven universal property. Implement the property generally — do not hard-code only the fixture's case.
- You may refactor existing code. Tests and proofs are the specification; existing structure is not. If the cleanest path to green touches adjacent files, take it.
- Use the domain identifiers listed under "Domain vocabulary" — do not invent new names. Future `explain` and `measure-entailment` runs depend on the code and the Prolog facts sharing vocabulary.
- Do not modify anything under `thoughts/`.
- Do not weaken assertions, skip tests, or disable type checks.
- Do not alter other tests in the generated file.
- Run the full project test suite and the type check yourself before returning. Report what you ran and what passed.
```

---

## Removal rules block

Used for `test_category(projection)` tests whose cited claim has `claim_label(_, counterfactual)`.

```markdown
## Rules

- **The action is deletion, not addition.** The counterfactual claim above was proven load-bearing for the downstream property — the property holds only when this fact is absent from the codebase. Do not add a new abstraction, feature flag, wrapper, or indirection to "hide" the fact. Delete its source.
- The expected change is removal of an import, call, config entry, export, or dependency — not the creation of new code. If you find yourself adding a file or a function to make the test pass, stop and reconsider.
- Do not add shims, re-exports, or alias modules that keep the forbidden identifier reachable under a different name. "Moving the dependency" is not removing it.
- If removing the fact breaks pre-existing green tests, those tests themselves were relying on the forbidden dependency — report the situation, do not silently delete or alter them. Escalation will be decided by the orchestrator.
- Use the file:line list under "Source locations for this fact" as the authoritative target of deletion. If the locator marks the fact `ALREADY_ABSENT`, halt and report — the test's failure is not a deletion-work signal in that case.
- Do not modify anything under `thoughts/`.
- Do not weaken assertions, skip tests, or disable type checks.
- Do not alter other tests in the generated file.
- Run the full project test suite and the type check yourself before returning. Report what you ran and what passed.
```

### `negation_provenance` interpretive notes

The briefer copies one of these two notes under the `negation_provenance` line of a removal briefing.

**If `negation_provenance(_, absent)`:**

> The proof relies on the closed-world reading that this fact is not in the KB. Removing the source is a CWA refactor — fragile against KB completeness. After removal, if the test still fails, the cause is more likely an incomplete hypothesis than a missing deletion. Report carefully so the orchestrator can route to a `decompose-proposition` revisit.

**If `negation_provenance(_, contradicts)`:**

> The explicit-conflict premise is structurally enforced. Removing the source must not re-introduce the conflict elsewhere — the proof's conflict premise will trip if the same conflicting pair reappears under a different name. After removal, verify no equivalent conflicting fact remains.

---

## Behavioral rules block

Used for `test_category(behavioral_claim)` tests. There is no upstream proof, no `claim/2`, no `theorem_verdict/2`. The test is the specification.

```markdown
## Rules

- This test is a TDD-layer behavioral contract — I/O, state, timing, concurrency, or side effect. There is no upstream proof or hypothesis claim backing it. The test text and the failure output are the specification.
- The implementation is a matter of engineering judgment, not proof projection. Use the codebase's existing idioms for the behavior being asserted. If the test needs test doubles, clock injection, or process-level observation, use the infrastructure listed under "Behavioral-contract infrastructure" — do not invent a new harness.
- **Do not treat a passing behavioral_claim test as equivalent in strength to a passing projection test.** A green run means "the fixture passed on this attempt," not "the property is verified." When you summarise the change, use the phrase "behavioral witness," not "property verified."
- You may refactor existing code. The test is the specification; existing structure is not. If the cleanest path to green touches adjacent files, take it.
- Do not modify anything under `thoughts/`.
- Do not weaken assertions, skip tests, or disable type checks.
- Do not alter other tests in the generated file.
- Run the full project test suite and the type check yourself before returning. Report what you ran and what passed.
```

---

## Why these are extracted

`SKILL.md` for `realize-specification` previously inlined three briefing templates, each carrying a copy of the same rules. Pulling them here means:

- The briefer agent has one canonical source for the rule blocks. Drift between the inline copy and the agent's understanding is impossible.
- Updating a rule (e.g., a new "do not modify CI config" guard) is one edit here, not three.
- The orchestrator's `SKILL.md` shrinks — its concern is routing and verification, not the per-shape rule text.

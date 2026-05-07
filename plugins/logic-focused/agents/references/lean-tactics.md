# Lean tactic reference for `lean-expert`

Worked examples per tactic family, keyed to the canonical claim shapes of the
ontology. The agent prompt in `agents/lean-expert.md` lists the families; this
file shows what each looks like in practice. Source for every "validated"
example is `~/Projects/deltadental/wt/BE/2312-extra/thoughts/lean/Proofs/InvoiceProperties.lean`
unless noted otherwise.

## 1. Spec-shaped proofs (default)

The default shape for a target-world theorem is a quantified invariant
closed by a short structural tactic chain.

### 1a. Empty inductive (vacuous universal)

The Prolog domain has values, but the predicate has no ground facts asserting
membership. The theorem says "no element of the domain has the property";
proof closes by case analysis on the (zero-constructor) inductive predicate.

```lean
@[ontology .descriptive, .absent]
theorem fp_i05 : ∀ n : LobNotice, ¬ ChangedNoticeIn2312 n := by
  intro n h; cases h
```

The `cases h` step has no cases to dispatch (the predicate has no
constructors), so the goal closes vacuously.

Equivalent using the scaffold's `exhaust` macro:

```lean
@[ontology .descriptive, .absent]
theorem fp_i05 : ∀ n : LobNotice, ¬ ChangedNoticeIn2312 n := by
  intro n; exhaust
```

### 1b. Cross-predicate disjointness

Two finite predicates over a shared domain whose constructors do not overlap.
Proof closes by case analysis on both predicates simultaneously — every pair
of constructors yields kernel-level index disagreement.

```lean
@[ontology .counterfactual, .contradicts]
theorem fp_i01_sufficient :
    ∀ k v, SeededValue k v → ¬ IsExternalId v := by
  intro k v h hext; cases h <;> cases hext
```

### 1c. Intra-predicate invariant — the load-bearing case

The Prolog domain has multiple constructors; the theorem says "every fact
matching predicate `P` at a specific second argument has its first argument
fixed at value X." Proof closes in two tactics: `intro v h; cases h <;> rfl`.
The `rfl` discharges the surviving case; `cases` eliminates the others by
index disagreement on the second argument.

```lean
@[ontology .descriptive, .absent]
theorem fp_i03 :
    ∀ v : ArtifactVariant, ArtifactIncludes v .audit_footer → v = .azure_stored := by
  intro v h
  cases h <;> rfl
```

This is the form most often needed for non-trivial structural claims.
Two tactics over a five-constructor predicate.

### 1d. Witnessed conjunction (prescriptive)

The theorem asserts that several specific facts hold simultaneously. Proof is
a constructor list using the scaffold's `witnesses` macro.

```lean
@[ontology .prescriptive, .absent]
theorem fp_i07 :
    SeededValue .InvoiceNoticePhysicalMail .InternalPhysicalPath ∧
    SeededValue .InvoiceNoticeEmail        .InternalEmailPath := by
  witnesses .physical_internal, .email_internal
```

Mixed witnesses with sub-goals: `witnesses .a, .b, ?_, ?_` leaves the trailing
two as new goals that close with `exhaust` (for impossibility sub-claims) or
explicit constructor witnesses on a CF-augmented predicate (for the
necessity-adjacent-to-prescriptive pattern).

## 2. Concept-validation proofs (legitimate when warranted)

Some claims do not have a spec-shaped form. The classic case is a necessity
lemma: a proof that re-introducing a counterfactually-removed fact would
break the invariant.

### 2a. Witnessed existential (necessity lemma)

```lean
@[ontology .counterfactual, .contradicts]
theorem fp_i01_needs_cf1 :
    ∃ k v, SeededValueCF1 k v ∧ IsExternalId v := by
  exact ⟨.InvoiceNoticePhysicalMail, .LobTemplateId, .lob_template_id, .lob_template⟩
```

The CF-augmented predicate `SeededValueCF1` mirrors `SeededValue` plus the
counterfactually-removed pair `.InvoiceNoticePhysicalMail ↦ .LobTemplateId`.
The witness chain proves the property fails in the CF-extended world, which
establishes that the counterfactual was load-bearing.

This is concept-validation: the theorem demonstrates that the CF removal
matters. It is not a spec-shaped statement of the underlying invariant.

## 3. The forbidden tactics — before/after pairs

Each before/after pair shows a theorem that *would* have closed by a
forbidden tactic under the old transcription path, paired with the validated
form after Layer 1 lifts the domain to inductive enums.

### 3a. `decide` over a `String`-indexed list (FORBIDDEN)

**Before** — closes by `decide` over a transcribed list:

```lean
def seededValues : List (String × String × String) :=
  [ ("InvoiceNoticePhysicalMail", "Common/Templates/Physical/Invoice.hbs", "InternalPhysicalPath")
  , ("InvoiceNoticeEmail",        "Common/Templates/Email/Invoice.html",    "InternalEmailPath") ]

theorem seededHasPhysical :
    ("InvoiceNoticePhysicalMail", "Common/Templates/Physical/Invoice.hbs",
     "InternalPhysicalPath") ∈ seededValues := by
  decide
```

The proof is structurally vacuous. Lean is type-checking that a tuple appears
in a list literal — no kernel guarantee that earns its keep.

**After** — closes by structural tactic on inductive predicate:

```lean
@[ontology .prescriptive, .absent]
theorem seededHasPhysical : SeededValue .InvoiceNoticePhysicalMail .InternalPhysicalPath := by
  exact .physical_internal
```

The constructor `.physical_internal` *is* the proof. The closed-domain types
make the inhabitant exhaustive by construction; no `decide` needed.

### 3b. `generalize` to enable `cases` on a `String`-indexed predicate (FORBIDDEN)

**Before**:

```lean
theorem noPhysicalAuditFooter :
    ¬ ArtifactIncludes "lob_bound" "audit_footer" := by
  intro h
  generalize hkey : "lob_bound" = key at h  -- workaround attempt
  cases h <;> ...  -- still fails, kernel doesn't unify Strings
```

The `generalize` here is an attempt to abstract the concrete-string indices
so `cases` can dispatch them. It does not work — `String` is not an inductive
enum, and `nomatch` / `rintro` over it fall back to propositional-equality
machinery rather than kernel disjointness.

**After** — domain lifted to inductive enum:

```lean
inductive ArtifactVariant where
  | lob_bound | sendgrid_attachment | azure_stored
  deriving DecidableEq, Repr

inductive ArtifactContent where
  | shared_invoice_body | address_overlay_zone_empty | audit_footer
  deriving DecidableEq, Repr

inductive ArtifactIncludes : ArtifactVariant → ArtifactContent → Prop where
  | lob_shared      : ArtifactIncludes .lob_bound           .shared_invoice_body
  | lob_address     : ArtifactIncludes .lob_bound           .address_overlay_zone_empty
  | sendgrid_shared : ArtifactIncludes .sendgrid_attachment .shared_invoice_body
  | azure_shared    : ArtifactIncludes .azure_stored        .shared_invoice_body
  | azure_audit     : ArtifactIncludes .azure_stored        .audit_footer

@[ontology .descriptive, .absent]
theorem noLobAuditFooter : ¬ ArtifactIncludes .lob_bound .audit_footer := by
  intro h; cases h
```

`cases h` now closes by kernel-level index disagreement on the second
argument across every constructor. No workaround needed because the domain
types are inductive enums.

## 4. Reading the table

When picking a tactic for a target-world theorem, locate the claim shape in
the table below and reach for the matching family first.

| Claim shape | Theorem form | First-choice tactic |
|---|---|---|
| Vacuous universal over empty inductive | `∀ n : T, ¬ P n` | `intro n; exhaust` |
| Cross-predicate disjointness | `∀ … P x → ¬ Q y` | `intro …; cases hP <;> cases hQ` |
| Intra-predicate invariant | `∀ x …, P x y → x = a` | `intro …; cases h <;> rfl` |
| Conjunction of required facts | `P a b ∧ P c d ∧ …` | `witnesses .c1, .c2, ...` |
| Witnessed existential (necessity) | `∃ x …, PCF x ∧ Q x` | `exact ⟨witness, .c, ...⟩` |

Anything else — induction over naturals or lists, algebraic rewriting,
order-theoretic claims, fixed-point arguments — falls outside the scaffold and
back into the broader Mathlib + structural toolkit. Reach for `induction`,
`omega`, `linarith`, `simp`, `rw`, and Mathlib lemmas in those cases.

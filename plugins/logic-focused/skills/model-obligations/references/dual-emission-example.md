# Dual emission — `target-world-shape.lean` worked example

The Lean shape file declares:

- **One inductive enum type per closed Prolog domain.** Each distinct atom in a closed argument position becomes a constructor. Domains tagged `provenance(_, descriptive)` and `provenance(_, prescriptive)` whose values are simple atoms with no path separators, file extensions, or hash-shaped patterns, and whose distinct count is small (rule of thumb: ≤ 20 values), are closed. Genuinely-open domains (file paths, free-form identifiers, content pulled from external systems) stay as `String`.
- **One inductive `Prop` per Prolog predicate, with one constructor per ground fact.** Constructor names should describe the ground tuple in named terms — `lob_shared`, `notification_pdf_renderer` — not positional.
- **For each counterfactual claim, a parallel CF-augmented inductive predicate** (`PCF1`, `PCF2`, …) that mirrors the target-world predicate plus the counterfactually-removed constructor. The necessity lemma proves the property fails in the CF-extended world by direct constructor citation.

Worked example, lifted from the 2312-Extra rework (source: `~/Projects/deltadental/wt/BE/2312-extra/thoughts/lean/Proofs/InvoiceProperties.lean`):

```lean
import Ontology.Prelude

set_option autoImplicit false

namespace TargetWorld

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

-- Counterfactual augmentation: re-introduce a previously-removed pair.
inductive ArtifactIncludesCF1 : ArtifactVariant → ArtifactContent → Prop where
  | lob_shared          : ArtifactIncludesCF1 .lob_bound           .shared_invoice_body
  | lob_address         : ArtifactIncludesCF1 .lob_bound           .address_overlay_zone_empty
  | sendgrid_shared     : ArtifactIncludesCF1 .sendgrid_attachment .shared_invoice_body
  | azure_shared        : ArtifactIncludesCF1 .azure_stored        .shared_invoice_body
  | azure_audit         : ArtifactIncludesCF1 .azure_stored        .audit_footer
  | sendgrid_audit_back : ArtifactIncludesCF1 .sendgrid_attachment .audit_footer

end TargetWorld
```

The `prove-invariants` skill then states theorems in quantified-invariant form over these declarations — `∀ v, ArtifactIncludes v .audit_footer → v = .azure_stored` closes by `intro v h; cases h <;> rfl`. The kernel handles the index disagreement case-by-case rather than reducing to a `decide`-over-list call.

## Domain-typing decisions are hand-curated per ticket

The tiered classifier sketched in the structural-translation ticket (Tier 1 / Tier 2 / Tier 3) is intentionally **on hold**. For v1, decide per-position case-by-case as target-world is constructed: lift Prolog atoms to inductive enum constructors when the domain is small and the values are simple atoms; leave the position as `String` when the domain is open. Bias toward false-open — a falsely-closed domain over-commits to KB completeness and makes Lean's `cases h` exhaust only the enumerated subset; a falsely-open domain degrades to `decide`-over-list, trips the lean-expert hard rule, and surfaces the misclassification recoverably.

The classifier may land in a future iteration if the case-by-case decisions prove repetitive enough to mechanize. Do not implement it speculatively.

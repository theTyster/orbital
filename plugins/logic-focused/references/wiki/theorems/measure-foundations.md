# Measure Foundations

[Back to Index](../index.md)

Countable additivity, subadditivity, and measure extensionality.

---

### `MeasureTheory.measure_iUnion_le`
**Countable subadditivity**: `μ(⋃ Aₙ) ≤ ∑ μ(Aₙ)`.
```lean
example [MeasurableSpace α] (μ : MeasureTheory.Measure α) (s : Nat → Set α) :
    μ (⋃ n, s n) ≤ ∑' n, μ (s n) := MeasureTheory.measure_iUnion_le s
```

### `MeasureTheory.measure_iUnion`
**Countable additivity** (disjoint): `μ(⋃ Aₙ) = ∑ μ(Aₙ)` when the sets are pairwise disjoint.
```lean
-- measure_iUnion for pairwise disjoint measurable sets
```

### `MeasureTheory.Measure.ext`
Two measures agreeing on all measurable sets are equal.
```lean
-- Measure extensionality
```

### `MeasureTheory.exists_measurable_superset_of_null`
Every null set is contained in a measurable null set.
```lean
-- Used in completion of measure spaces
```

### `MeasureTheory.ae_eq_of_forall_setIntegral_eq`
If two `L¹` functions have equal integrals over every measurable set, they're equal a.e.
```lean
-- Fundamental lemma of the calculus of variations (measure theory version)
```

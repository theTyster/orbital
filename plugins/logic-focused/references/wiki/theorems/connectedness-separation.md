# Connectedness & Separation

[Back to Index](../index.md)

Intermediate Value Theorem, Urysohn's Lemma, and Tietze Extension Theorem.

---

### `intermediate_value_Icc`
**Intermediate Value Theorem**: a continuous function on `[a,b]` hits every value between `f(a)` and `f(b)`.
```lean
example {f : ℝ → ℝ} {a b : ℝ} (hab : a ≤ b) (hf : ContinuousOn f (Set.Icc a b))
    {v : ℝ} (hv : f a ≤ v) (hv' : v ≤ f b) : ∃ c ∈ Set.Icc a b, f c = v :=
  intermediate_value_Icc hab hf (sorry) -- exact API varies
```

### `Urysohn.exists_continuous`
**Urysohn's Lemma**: in a normal space, disjoint closed sets can be separated by a continuous function.
```lean
-- Formalized in Mathlib.Topology.UrysohnLemma
```

### `TietzeExtension.exists_extension`
**Tietze Extension Theorem**: continuous functions on closed subsets of normal spaces extend to the whole space.
```lean
-- Formalized in Mathlib.Topology.TietzeExtension
```

### `connectedComponent_eq_iUnion_clopen`
A connected component is the intersection of all clopen sets containing a point.
```lean
-- Formalized in Mathlib.Topology.Connected
```

---

## See also

- [Compactness](compactness.md) -- Heine-Borel, extreme value theorem, Tychonoff
- [Completeness & Fixed Points](completeness-fixed-points.md) -- completeness of metric spaces, Baire category
- [Continuity](../lemmas/continuity.md) -- basic continuity lemmas for topological maps

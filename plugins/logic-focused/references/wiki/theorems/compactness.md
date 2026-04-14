# Compactness

[Back to Index](../index.md)

Heine-Borel, Extreme Value Theorem, Heine-Cantor, and Tychonoff's theorem.

---

### `Metric.isCompact_iff_isClosed_bounded`
**Heine-Borel theorem** (for proper metric spaces): compact iff closed and bounded.
```lean
-- In ℝⁿ: isCompact_iff_isClosed_bounded
```

### `IsCompact.exists_isMinOn`
**Extreme Value Theorem** (minimum): a continuous function on a compact set attains its minimum.
```lean
example [TopologicalSpace α] [TopologicalSpace β] [ConditionallyCompleteLinearOrder β]
    [OrderTopology β] {f : α → β} {s : Set α} (hs : IsCompact s) (hne : s.Nonempty)
    (hf : ContinuousOn f s) : ∃ x ∈ s, ∀ y ∈ s, f x ≤ f y :=
  hs.exists_isMinOn hne hf
```

### `IsCompact.exists_isMaxOn`
**Extreme Value Theorem** (maximum): a continuous function on a compact set attains its maximum.
```lean
example [TopologicalSpace α] [TopologicalSpace β] [ConditionallyCompleteLinearOrder β]
    [OrderTopology β] {f : α → β} {s : Set α} (hs : IsCompact s) (hne : s.Nonempty)
    (hf : ContinuousOn f s) : ∃ x ∈ s, ∀ y ∈ s, f y ≤ f x :=
  hs.exists_isMaxOn hne hf
```

### `ContinuousOn.uniformContinuousOn_of_isCompact`
**Heine-Cantor theorem**: a continuous function on a compact set is uniformly continuous.
```lean
-- UniformContinuousOn from ContinuousOn + IsCompact
```

### `IsCompact.isClosed`
Compact subsets of Hausdorff spaces are closed.
```lean
example [TopologicalSpace α] [T2Space α] {s : Set α} (hs : IsCompact s) : IsClosed s :=
  hs.isClosed
```

### `CompactSpace.isCompact_univ`
**Tychonoff's theorem**: the product of compact spaces is compact (baked into Mathlib's product topology).
```lean
example [∀ i, TopologicalSpace (α i)] [∀ i, CompactSpace (α i)] :
    CompactSpace (∀ i, α i) := inferInstance
```

### `IsCompact.finite`
**Compact discrete sets are finite**: a compact set in a discrete topology is finite.
```lean
example [TopologicalSpace α] [DiscreteTopology α] {s : Set α} (hs : IsCompact s) :
    s.Finite := hs.finite
```

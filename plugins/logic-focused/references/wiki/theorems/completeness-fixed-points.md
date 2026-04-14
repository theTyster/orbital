# Completeness & Fixed Points

[Back to Index](../index.md)

Completeness of ℝ, Banach fixed point theorem, and Baire category theorem.

---

### `CompleteSpace`
**Completeness of ℝ**: every Cauchy sequence converges. `ℝ` is a `CompleteSpace`.
```lean
example : CompleteSpace ℝ := inferInstance
```

### `contracting_with_fixedPoint`
**Banach Fixed Point Theorem**: a contraction mapping on a complete metric space has a unique fixed point.
```lean
-- ContractingWith.fixedPoint_unique in Mathlib
```

### `BaireSpace`
**Baire Category Theorem**: a complete metric space is not a countable union of nowhere dense sets.
```lean
example : BaireSpace ℝ := inferInstance
```

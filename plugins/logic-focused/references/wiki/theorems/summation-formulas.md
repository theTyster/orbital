# Summation Formulas

[Back to Index](../index.md)

Classical summation identities formalized in Mathlib.

---

### `Nat.arithmetic_sum`
**Gauss's summation formula**: `∑ i in range n, i = n * (n - 1) / 2`
```lean
-- Available via Finset.sum_range_id or Gauss.sum_range
example (n : Nat) : ∑ i in Finset.range n, i = n * (n - 1) / 2 := sorry -- exact name varies
```

### `Finset.sum_geometric`
**Geometric series formula**: `∑ i in range n, r^i = (r^n - 1)/(r - 1)`
```lean
-- Formalized for various ring types
example [Field α] (r : α) (hr : r ≠ 1) (n : Nat) :
    ∑ i in Finset.range n, r ^ i = (r ^ n - 1) / (r - 1) :=
  sorry -- geom_sum_eq hr n or similar
```

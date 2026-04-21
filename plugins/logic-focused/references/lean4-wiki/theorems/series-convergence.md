# Series & Convergence

[Back to Index](../index.md)

Convergence of series, geometric sums, and the Basel problem.

---

### `hasSum_geometric_of_lt_one`
**Geometric series convergence**: `∑ r^n = 1/(1-r)` for `|r| < 1`.
```lean
example (r : Real) (hr0 : 0 ≤ r) (hr1 : r < 1) :
    HasSum (fun n => r ^ n) (1 - r)⁻¹ := hasSum_geometric_of_lt_one hr0 hr1
```

### `Real.summable_geometric_of_lt_one`
The geometric series `∑ r^n` is summable when `0 ≤ r < 1`.
```lean
example (r : Real) (hr0 : 0 ≤ r) (hr1 : r < 1) :
    Summable (fun n => r ^ n) := summable_geometric_of_lt_one hr0 hr1
```

### `Real.tendsto_pow_atTop`
Powers of numbers > 1 tend to infinity.
```lean
-- Filter.Tendsto (fun n => r ^ n) Filter.atTop Filter.atTop when 1 < r
```

### `Real.hasSum_inv_nat_sq` / `Basel.hasSum`
**Basel problem**: `∑ 1/n² = π²/6`.
```lean
-- Formalized in Mathlib; exact name may be hasSum_zeta_two or similar
```

---

## See also

- [Summation Formulas](summation-formulas.md) -- finite geometric sums and Gauss's formula
- [Integration](integration.md) -- convergence theorems for integrals (dominated convergence, monotone convergence)
- [Real Functions](../lemmas/real-functions.md) -- basic lemmas about real-valued functions

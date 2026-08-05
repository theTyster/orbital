# Probability

[Back to Index](../index.md)

Strong Law of Large Numbers, Central Limit Theorem, and variance bounds.

---

### `ProbabilityTheory.strong_law`
**Strong Law of Large Numbers**: sample means converge almost surely.
```lean
-- Formalized in Mathlib.Probability.StrongLaw
```

### `ProbabilityTheory.central_limit`
**Central Limit Theorem**: normalized sums converge in distribution to a Gaussian.
```lean
-- Partial formalizations exist in Mathlib
```

### `ProbabilityTheory.variance_le_expectation_sq`
`Var(X) ≤ E[X²]` (since `Var(X) = E[X²] - E[X]²`).
```lean
-- Formalized in Mathlib.Probability.Variance
```

---

## See also

- [Measure Foundations](measure-foundations.md) -- countable additivity, subadditivity underlying probability
- [Inequalities](inequalities.md) -- Holder's, Minkowski's, and Cauchy-Schwarz inequalities

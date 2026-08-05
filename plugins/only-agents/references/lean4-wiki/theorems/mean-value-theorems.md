# Mean Value Theorems

[Back to Index](../index.md)

Rolle's theorem, Mean Value Theorem, Fermat's stationary points, and Taylor's theorem.

---

### Rolle's Theorem
**Rolle's theorem**: if `f(a) = f(b)` and `f` is differentiable on `(a,b)`, there exists `c ∈ (a,b)` with `f'(c) = 0`.
```lean
-- exists_hasDerivAt_eq_zero or Rolle's formulation in Mathlib
```

### `exists_ratio_hasDerivAt_eq_ratio_slope`
**Mean Value Theorem**: there exists `c ∈ (a,b)` with `f'(c) = (f(b) - f(a))/(b - a)`.
```lean
-- exists_hasDerivAt_eq_slope or exists_ratio_hasDerivAt_eq_ratio_slope
```

### `IsLocalMin.hasDerivAt_eq_zero`
**Fermat's theorem on stationary points**: if `f` has a local extremum at `x` and is differentiable there, then `f'(x) = 0`.
```lean
example {f : ℝ → ℝ} {f' x : ℝ} (hmin : IsLocalMin f x) (hf : HasDerivAt f f' x) :
    f' = 0 := hmin.hasDerivAt_eq_zero hf
```

### `MonotonOn.of_deriv_nonneg`
If `f' ≥ 0` on an interval, then `f` is monotone on that interval.
```lean
-- MonotonOn from non-negative derivative
```

### `StrictMono.of_deriv_pos`
If `f' > 0` on an interval, then `f` is strictly monotone.
```lean
-- StrictMonoOn from positive derivative
```

### `taylorMeanIntRemainder`
**Taylor's theorem** with integral remainder.
```lean
-- Formalized in Mathlib.Analysis.Calculus.Taylor
```

---

## See also

- [Differentiation Rules](differentiation-rules.md) -- sum, product, chain, and quotient rules
- [Standard Derivatives](standard-derivatives.md) -- derivatives of exp, log, sin, cos
- [Integration](integration.md) -- Fundamental Theorem of Calculus connecting derivatives and integrals

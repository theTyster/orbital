# Standard Derivatives

[Back to Index](../index.md)

Derivatives of elementary functions: exp, log, sin, cos.

---

### `Real.hasDerivAt_exp`
`(exp)' = exp`.
```lean
example (x : ℝ) : HasDerivAt Real.exp (Real.exp x) x := Real.hasDerivAt_exp x
```

### `Real.hasDerivAt_log`
`(log)' = 1/x` for `x ≠ 0`.
```lean
example (x : ℝ) (hx : x ≠ 0) : HasDerivAt Real.log x⁻¹ x := Real.hasDerivAt_log hx
```

### `Real.hasDerivAt_sin`
`(sin)' = cos`.
```lean
example (x : ℝ) : HasDerivAt Real.sin (Real.cos x) x := Real.hasDerivAt_sin x
```

### `Real.hasDerivAt_cos`
`(cos)' = -sin`.
```lean
example (x : ℝ) : HasDerivAt Real.cos (-Real.sin x) x := Real.hasDerivAt_cos x
```

---

## See also

- [Differentiation Rules](differentiation-rules.md) -- sum, product, chain, and quotient rules
- [Mean Value Theorems](mean-value-theorems.md) -- MVT, Rolle's theorem, Taylor's theorem
- [Real Functions](../lemmas/real-functions.md) -- basic real function lemmas

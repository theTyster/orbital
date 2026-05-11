# Inequalities

[Back to Index](../index.md)

Cauchy-Schwarz, triangle inequality, AM-GM, Holder, and Minkowski.

---

### `abs_inner_le_norm`
**Cauchy-Schwarz inequality**: `|⟨x, y⟩| ≤ ‖x‖ * ‖y‖`.
```lean
example [InnerProductSpace ℝ E] (x y : E) :
    |inner x y| ≤ ‖x‖ * ‖y‖ := abs_inner_le_norm x y
```

### `norm_add_le`
**Triangle inequality** (normed spaces): `‖x + y‖ ≤ ‖x‖ + ‖y‖`.
```lean
example [NormedAddCommGroup E] (x y : E) : ‖x + y‖ ≤ ‖x‖ + ‖y‖ := norm_add_le x y
```

### `dist_triangle`
**Triangle inequality** (metric spaces): `dist x z ≤ dist x y + dist y z`.
```lean
example [MetricSpace α] (x y z : α) : dist x z ≤ dist x y + dist y z := dist_triangle x y z
```

### AM-GM Inequality
**AM-GM inequality**: `a * b ≤ (a² + b²) / 2` (and generalizations).
```lean
-- Two-variable: use sq_nonneg to prove (a - b)^2 ≥ 0 implies 2ab ≤ a² + b²
example (a b : Real) : a * b ≤ (a ^ 2 + b ^ 2) / 2 := by nlinarith [sq_nonneg (a - b)]
```

### `MeasureTheory.integral_mul_le`
**Holder's inequality**: `∫ |fg| ≤ (∫ |f|^p)^(1/p) * (∫ |g|^q)^(1/q)`.
```lean
-- NNReal.inner_le_Lnorm_mul_Lnorm or MeasureTheory.inner_le_Lnorm_mul_Lnorm
```

### `MeasureTheory.Memℒp.add`
**Minkowski's inequality**: `‖f + g‖_p ≤ ‖f‖_p + ‖g‖_p` (triangle inequality in Lp).
```lean
-- Formalized via the Lp space construction in Mathlib
```

---

## See also

- [Absolute Value & Norms](../lemmas/absolute-value-norms.md) -- basic norm and absolute value lemmas
- [Inner Product & Geometry](inner-product-geometry.md) -- inner product space structure and Cauchy-Schwarz context
- [Hilbert & Banach Spaces](hilbert-banach-spaces.md) -- operator norms and functional analysis

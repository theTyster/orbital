# Inner Product Geometry

[Back to Index](../index.md)

Pythagorean theorem, parallelogram law, and Cauchy-Schwarz in inner product spaces.

---

### Pythagorean Theorem
**Pythagorean theorem** (in inner product spaces): `‖x + y‖² = ‖x‖² + ‖y‖²` when `⟨x, y⟩ = 0`.
```lean
example [InnerProductSpace ℝ E] (x y : E) (h : inner x y = (0 : ℝ)) :
    ‖x + y‖ ^ 2 = ‖x‖ ^ 2 + ‖y‖ ^ 2 := by
  rw [norm_add_sq_real, h, mul_zero, add_zero]
```

### `abs_inner_le_norm`
**Cauchy-Schwarz** (inner product form): `|⟨x,y⟩| ≤ ‖x‖ · ‖y‖`.
```lean
example [InnerProductSpace ℝ E] (x y : E) : |inner x y| ≤ ‖x‖ * ‖y‖ :=
  abs_inner_le_norm x y
```

### Parallelogram Law
**Parallelogram law**: `‖x + y‖² + ‖x - y‖² = 2(‖x‖² + ‖y‖²)`.
```lean
example [InnerProductSpace ℝ E] (x y : E) :
    ‖x + y‖ ^ 2 + ‖x - y‖ ^ 2 = 2 * (‖x‖ ^ 2 + ‖y‖ ^ 2) :=
  parallelogram_law_with_norm ℝ x y -- or similar
```

---

## See also

- [Hilbert & Banach Spaces](hilbert-banach-spaces.md) -- Riesz representation, operator norms in functional analysis
- [Inequalities](inequalities.md) -- Cauchy-Schwarz, triangle inequality, AM-GM
- [Absolute Value & Norms](../lemmas/absolute-value-norms.md) -- basic norm and absolute value lemmas

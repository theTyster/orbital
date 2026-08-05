# Hilbert & Banach Spaces

[Back to Index](../index.md)

Orthogonal projection, Riesz representation, and operator norms in functional analysis.

---

### `Submodule.existsUnique_orthogonalProjection`
**Orthogonal projection theorem**: every element of a Hilbert space has a unique closest point in a closed subspace.
```lean
-- orthogonalProjection in Mathlib.Analysis.InnerProductSpace.Projection
```

### `InnerProductSpace.toDual`
**Riesz Representation** (Hilbert spaces): `H* ≅ H` via the inner product.
```lean
-- toDualMap or InnerProductSpace.toDual
```

### `ContinuousLinearMap.opNorm_le_bound`
**Bounded linear operators** have a finite operator norm.
```lean
-- ‖f‖ ≤ C when ‖f x‖ ≤ C * ‖x‖ for all x
```

### `LinearIsometry.norm_map`
Isometries preserve norms: `‖f x‖ = ‖x‖`.
```lean
example [NormedAddCommGroup E] [NormedSpace ℝ E] [NormedAddCommGroup F] [NormedSpace ℝ F]
    (f : E →ₗᵢ[ℝ] F) (x : E) : ‖f x‖ = ‖x‖ := f.norm_map x
```

### `InnerProductSpace.norm_sq_eq_inner`
`‖x‖² = ⟨x, x⟩` (definition linking norm and inner product).
```lean
example [InnerProductSpace ℝ E] (x : E) : ‖x‖ ^ 2 = inner x x :=
  real_inner_self_eq_norm_sq x |>.symm
```

### `IsOpenMap` / Open Mapping Theorem
**Open Mapping Theorem** (Banach-Schauder): a surjective bounded linear map between Banach spaces is an open map.
```lean
-- Mathlib: Analysis.NormedSpace.OperatorNorm and Analysis.NormedSpace.BanachSteinhaus
-- IsOpenMap.of_surjective_continuousLinearMap (surjective bounded linear maps are open)
```

### `banach_steinhaus` / Uniform Boundedness Principle
A pointwise bounded family of continuous linear maps on a Banach space is uniformly bounded.
```lean
-- Mathlib: Analysis.NormedSpace.BanachSteinhaus
-- banach_steinhaus : ... → ∃ C, ∀ f ∈ F, ‖f‖ ≤ C
```

---

## See also

- [Inequalities](inequalities.md) -- Cauchy-Schwarz, triangle inequality, Holder, Minkowski
- [Inner Product & Geometry](inner-product-geometry.md) -- inner product space fundamentals
- [Completeness & Fixed Points](completeness-fixed-points.md) -- completeness of metric/normed spaces

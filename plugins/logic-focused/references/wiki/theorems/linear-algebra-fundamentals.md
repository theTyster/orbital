# Linear Algebra Fundamentals

[Back to Index](../index.md)

Rank-nullity, existence of bases, Riesz representation, and spectral theorem.

---

### `LinearMap.finrank_range_add_finrank_ker`
**Rank-Nullity Theorem**: `dim(im f) + dim(ker f) = dim(V)`.
```lean
example [DivisionRing K] [AddCommGroup V] [AddCommGroup W] [Module K V] [Module K W]
    [FiniteDimensional K V] (f : V →ₗ[K] W) :
    FiniteDimensional.finrank K (LinearMap.range f) +
    FiniteDimensional.finrank K (LinearMap.ker f) =
    FiniteDimensional.finrank K V :=
  f.finrank_range_add_finrank_ker
```

### `FiniteDimensional.finBasis`
Every finite-dimensional vector space over a division ring has a basis.
```lean
example [DivisionRing K] [AddCommGroup V] [Module K V] [FiniteDimensional K V] :
    ∃ b : Basis (Fin (FiniteDimensional.finrank K V)) K V, True :=
  ⟨FiniteDimensional.finBasis K V, trivial⟩
```

### `InnerProductSpace.toDual`
**Riesz Representation Theorem** (finite-dimensional): every continuous linear functional on a Hilbert space is inner product with a fixed vector.
```lean
-- InnerProductSpace.toDual is the canonical isometry V →ₗᵢ⋆[𝕜] Dual 𝕜 V
```

### `Matrix.IsHermitian.eigenvalues_real`
**Spectral theorem** (Hermitian matrices have real eigenvalues).
```lean
-- Formalized for IsHermitian matrices in Mathlib
```

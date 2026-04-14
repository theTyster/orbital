# Field & Galois Theory

[Back to Index](../index.md)

Tower law, Fundamental Theorem of Galois Theory, splitting fields, and algebraic closure.

---

### `FiniteDimensional.finrank_mul_finrank`
**Tower law**: `[L:K] = [L:M] * [M:K]` for field extensions.
```lean
example [Field K] [Field L] [Field M] [Algebra K M] [Algebra K L] [Algebra L M]
    [IsScalarTower K L M] [FiniteDimensional K L] [FiniteDimensional L M] :
    FiniteDimensional.finrank K M =
    FiniteDimensional.finrank K L * FiniteDimensional.finrank L M :=
  FiniteDimensional.finrank_mul_finrank K L M
```

### `IsGalois.intermediateFieldEquivSubgroup`
**Fundamental Theorem of Galois Theory**: there is an order-reversing bijection between intermediate fields and subgroups of the Galois group.
```lean
example [Field K] [Field L] [Algebra K L] [FiniteDimensional K L] [IsGalois K L] :
    IntermediateField K L ≃o (Subgroup (L ≃ₐ[K] L))ᵒᵈ :=
  IsGalois.intermediateFieldEquivSubgroup K L
```

### `Polynomial.IsSplittingField`
A polynomial splits completely over its splitting field.
```lean
-- The splitting field construction is in Mathlib.FieldTheory.SplittingField
```

### `IsAlgClosure`
**Existence of algebraic closure**: every field has an algebraic closure (unique up to isomorphism).
```lean
example [Field K] : IsAlgClosed (AlgebraicClosure K) := inferInstance
```

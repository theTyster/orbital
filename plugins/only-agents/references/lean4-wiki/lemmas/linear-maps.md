# Linear Maps

[Back to Index](../index.md)

Lemmas for linear map preservation of algebraic structure.

---

### `LinearMap.map_add`
Linear maps preserve addition.
```lean
example [Ring R] [AddCommGroup M] [AddCommGroup N] [Module R M] [Module R N]
    (f : M →ₗ[R] N) (x y : M) : f (x + y) = f x + f y := f.map_add x y
```

### `LinearMap.map_smul`
Linear maps preserve scalar multiplication.
```lean
example [CommRing R] [AddCommGroup M] [AddCommGroup N] [Module R M] [Module R N]
    (f : M →ₗ[R] N) (r : R) (x : M) : f (r • x) = r • f x := f.map_smul r x
```

### `LinearMap.map_zero`
Linear maps preserve zero.
```lean
example [Ring R] [AddCommGroup M] [AddCommGroup N] [Module R M] [Module R N]
    (f : M →ₗ[R] N) : f 0 = 0 := f.map_zero
```

### `LinearMap.ker`
**Kernel of a linear map** is a submodule: `ker f = {x | f x = 0}`.
```lean
example [Ring R] [AddCommGroup M] [AddCommGroup N] [Module R M] [Module R N]
    (f : M →ₗ[R] N) : Submodule R M := LinearMap.ker f
```

### `LinearMap.range`
**Range of a linear map** is a submodule: `range f = {y | ∃ x, f x = y}`.
```lean
example [Ring R] [AddCommGroup M] [AddCommGroup N] [Module R M] [Module R N]
    (f : M →ₗ[R] N) : Submodule R N := LinearMap.range f
```

---

## See also

- [Submodules](submodules.md) — submodule membership and closure properties
- [Linear Algebra Fundamentals](../theorems/linear-algebra-fundamentals.md) — rank-nullity theorem involving kernel and range of linear maps
- [Determinants & Trace](../theorems/determinants-trace.md) — matrix-level consequences of linear map structure

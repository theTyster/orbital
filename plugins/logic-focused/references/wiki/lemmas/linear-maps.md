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

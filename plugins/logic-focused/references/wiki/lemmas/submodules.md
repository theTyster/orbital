# Submodules

[Back to Index](../index.md)

Lemmas for submodule membership and closure properties.

---

### `Submodule.add_mem`
Sum of two elements in a submodule stays in the submodule.
```lean
example [Ring R] [AddCommGroup M] [Module R M] (S : Submodule R M)
    {x y : M} (hx : x ∈ S) (hy : y ∈ S) : x + y ∈ S := S.add_mem hx hy
```

### `Submodule.zero_mem`
Zero belongs to any submodule.
```lean
example [Ring R] [AddCommGroup M] [Module R M] (S : Submodule R M) : (0 : M) ∈ S :=
  S.zero_mem
```

### `Submodule.smul_mem`
A submodule is closed under scalar multiplication.
```lean
example [Ring R] [AddCommGroup M] [Module R M] (S : Submodule R M)
    (r : R) {x : M} (hx : x ∈ S) : r • x ∈ S := S.smul_mem r hx
```

---

## See also

- [Linear Maps](linear-maps.md) — linear maps that preserve submodule structure
- [Linear Algebra Fundamentals](../theorems/linear-algebra-fundamentals.md) — rank-nullity, bases, and the spectral theorem

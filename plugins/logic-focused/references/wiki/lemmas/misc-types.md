# Misc Types

[Back to Index](../index.md)

Lemmas for `Prod`, `Option`, `Fin`, `Equiv`, and `cast`.

---

### `Prod.ext_iff`
Two pairs are equal iff their components are equal.
```lean
example (p q : α × β) : p = q ↔ p.1 = q.1 ∧ p.2 = q.2 := Prod.ext_iff
```

### `Option.some_inj`
Injectivity of `Option.some`: `some a = some b ↔ a = b`
```lean
example (a b : α) : (some a : Option α) = some b ↔ a = b := Option.some_inj
```

### `Fin.ext_iff`
Two `Fin n` values are equal iff their underlying naturals are equal.
```lean
example {n : Nat} (a b : Fin n) : a = b ↔ a.val = b.val := Fin.ext_iff
```

### `Equiv.symm_apply_apply`
Applying an equivalence and its inverse: `e.symm (e a) = a`
```lean
example (e : α ≃ β) (a : α) : e.symm (e a) = a := e.symm_apply_apply a
```

### `Equiv.apply_symm_apply`
Applying an inverse and then the equivalence: `e (e.symm b) = b`
```lean
example (e : α ≃ β) (b : β) : e (e.symm b) = b := e.apply_symm_apply b
```

### `cast_eq`
Casting along a reflexivity proof: `cast rfl a = a`
```lean
example (a : α) : cast rfl a = a := cast_eq rfl a
```

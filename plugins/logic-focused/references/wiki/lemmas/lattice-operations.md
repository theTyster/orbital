# Lattice Operations

[Back to Index](../index.md)

Lemmas for supremum and infimum in lattice structures.

---

### `sup_le`
If `a ≤ c` and `b ≤ c` then `a ⊔ b ≤ c`.
```lean
example [SemilatticeSup α] (a b c : α) (h1 : a ≤ c) (h2 : b ≤ c) : a ⊔ b ≤ c :=
  sup_le h1 h2
```

### `le_inf`
If `a ≤ b` and `a ≤ c` then `a ≤ b ⊓ c`.
```lean
example [SemilatticeInf α] (a b c : α) (h1 : a ≤ b) (h2 : a ≤ c) : a ≤ b ⊓ c :=
  le_inf h1 h2
```

---

## See also

- [Order Relations](order-relations.md) — generic `le`, `lt`, `min`, `max` lemmas underlying lattice structure
- [Sets](sets.md) — set union and intersection form a lattice

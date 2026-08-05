# Tactic-Adjacent Lemmas

[Back to Index](../index.md)

Lemmas commonly used with `simp`, `ring`, `omega`, and `nlinarith` — inequalities, division, and conditional simplification.

---

### `mul_self_nonneg`
`a * a ≥ 0` in a linearly ordered ring.
```lean
example [LinearOrderedRing α] (a : α) : 0 ≤ a * a := mul_self_nonneg a
```

### `add_le_add`
If `a ≤ b` and `c ≤ d` then `a + c ≤ b + d`.
```lean
example [OrderedAddCommMonoid α] (a b c d : α) (h1 : a ≤ b) (h2 : c ≤ d) :
    a + c ≤ b + d := add_le_add h1 h2
```

### `add_le_add_left`
Adding the same thing on the left preserves `≤`.
```lean
example [OrderedAddCommMonoid α] (c : α) {a b : α} (h : a ≤ b) : c + a ≤ c + b :=
  add_le_add_left h c
```

### `add_le_add_right`
Adding the same thing on the right preserves `≤`.
```lean
example [OrderedAddCommMonoid α] (c : α) {a b : α} (h : a ≤ b) : a + c ≤ b + c :=
  add_le_add_right h c
```

### `mul_le_mul_of_nonneg_left`
Multiplying both sides by a non-negative value on the left preserves `≤`.
```lean
example [OrderedSemiring α] {a b c : α} (h : a ≤ b) (hc : 0 ≤ c) : c * a ≤ c * b :=
  mul_le_mul_of_nonneg_left h hc
```

### `if_pos` / `if_neg`
Simplify if-then-else when the condition is known.
```lean
example (h : True) : (if True then 1 else 0) = 1 := if_pos h
example (h : ¬False) : (if False then 1 else 0) = 0 := if_neg h
```

### `dif_pos` / `dif_neg`
Simplify dependent if-then-else.
```lean
example (h : True) : (dite True (fun _ => 1) (fun _ => 0)) = 1 := dif_pos h
```

---

## See also

- [Order Relations](order-relations.md) — `le_refl`, `le_trans`, `le_antisymm` used alongside `omega` and `linarith`
- [Ring & Field Operations](ring-field-operations.md) — `sq_nonneg`, distributivity used with `ring` and `nlinarith`

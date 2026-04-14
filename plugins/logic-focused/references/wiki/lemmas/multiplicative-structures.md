# Multiplicative Structures

[Back to Index](../index.md)

Typeclass-generic lemmas for multiplicative algebraic structures (`Monoid`, `CommMonoid`, `Group`, `Field`).

---

### `mul_comm`
Commutativity of multiplication in any `CommMonoid`.
```lean
example [CommMonoid α] (a b : α) : a * b = b * a := mul_comm a b
```

### `mul_assoc`
Associativity of multiplication in any `Semigroup`.
```lean
example [Semigroup α] (a b c : α) : a * b * c = a * (b * c) := mul_assoc a b c
```

### `one_mul`
Left identity for multiplication in any `Monoid`.
```lean
example [Monoid α] (a : α) : 1 * a = a := one_mul a
```

### `mul_one`
Right identity for multiplication in any `Monoid`.
```lean
example [Monoid α] (a : α) : a * 1 = a := mul_one a
```

### `mul_inv_cancel`
Right inverse in a group: `a * a⁻¹ = 1` (for `a ≠ 0` in a field).
```lean
example [Field α] (a : α) (h : a ≠ 0) : a * a⁻¹ = 1 := mul_inv_cancel₀ h
```

### `inv_mul_cancel`
Left inverse in a group: `a⁻¹ * a = 1`.
```lean
example [Field α] (a : α) (h : a ≠ 0) : a⁻¹ * a = 1 := inv_mul_cancel₀ h
```

### `mul_left_cancel`
Left cancellation in a group: if `a * b = a * c` then `b = c`.
```lean
example [Group α] (a b c : α) (h : a * b = a * c) : b = c := mul_left_cancel h
```

### `mul_right_cancel`
Right cancellation in a group: if `b * a = c * a` then `b = c`.
```lean
example [Group α] (a b c : α) (h : b * a = c * a) : b = c := mul_right_cancel h
```

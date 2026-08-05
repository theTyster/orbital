# Additive Structures

[Back to Index](../index.md)

Typeclass-generic lemmas for additive algebraic structures (`AddCommMonoid`, `AddSemigroup`, `AddGroup`).

---

### `add_comm`
Commutativity of addition in any `AddCommMonoid`.
```lean
example [AddCommMonoid α] (a b : α) : a + b = b + a := add_comm a b
```

### `add_assoc`
Associativity of addition in any `AddSemigroup`.
```lean
example [AddSemigroup α] (a b c : α) : a + b + c = a + (b + c) := add_assoc a b c
```

### `zero_add`
Left identity for addition in any `AddMonoid`.
```lean
example [AddMonoid α] (a : α) : 0 + a = a := zero_add a
```

### `add_zero`
Right identity for addition in any `AddMonoid`.
```lean
example [AddMonoid α] (a : α) : a + 0 = a := add_zero a
```

### `neg_add_cancel` / `add_left_neg`
Left inverse for addition in any `AddGroup`: `-a + a = 0`
```lean
example [AddGroup α] (a : α) : -a + a = 0 := neg_add_cancel a
```

### `add_neg_cancel` / `add_right_neg`
Right inverse for addition: `a + (-a) = 0`
```lean
example [AddGroup α] (a : α) : a + (-a) = 0 := add_neg_cancel a
```

### `sub_self`
Subtracting a value from itself: `a - a = 0`
```lean
example [AddGroup α] (a : α) : a - a = 0 := sub_self a
```

---

## See also

- [Multiplicative Structures](multiplicative-structures.md) — the multiplicative analogues of these additive lemmas
- [Nat Arithmetic](nat-arithmetic.md) — concrete addition lemmas for natural numbers
- [Ring & Field Operations](ring-field-operations.md) — distributivity connecting additive and multiplicative structure

# Natural Number Ordering

[Back to Index](../index.md)

Lemmas for ordering relations on natural numbers.

---

### `Nat.le_refl`
Every natural number is less than or equal to itself.
```lean
example (a : Nat) : a <= a := Nat.le_refl a
```

### `Nat.le_of_lt`
Strict less-than implies less-than-or-equal.
```lean
example (a b : Nat) (h : a < b) : a <= b := Nat.le_of_lt h
```

### `Nat.lt_of_lt_of_le`
Transitivity mixing strict and non-strict inequality.
```lean
example (a b c : Nat) (h1 : a < b) (h2 : b <= c) : a < c :=
  Nat.lt_of_lt_of_le h1 h2
```

### `Nat.lt_irrefl`
No natural number is strictly less than itself.
```lean
example (a : Nat) (h : a < a) : False := Nat.lt_irrefl a h
```

---

## See also

- [Order Relations](order-relations.md) -- generic ordering lemmas for any `PartialOrder` / `LinearOrder`
- [Natural Number Arithmetic](nat-arithmetic.md) -- arithmetic on `Nat`

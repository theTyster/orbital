# Powers & Exponents

[Back to Index](../index.md)

Lemmas for exponentiation in monoids and beyond.

---

### `pow_zero`
Any element to the power zero is one.
```lean
example [Monoid α] (a : α) : a ^ 0 = 1 := pow_zero a
```

### `pow_one`
Any element to the power one is itself.
```lean
example [Monoid α] (a : α) : a ^ 1 = a := pow_one a
```

### `pow_succ`
Power successor: `a ^ (n + 1) = a ^ n * a`
```lean
example [Monoid α] (a : α) (n : Nat) : a ^ (n + 1) = a ^ n * a := pow_succ a n
```

### `pow_add`
Power of a sum of exponents: `a ^ (m + n) = a ^ m * a ^ n`
```lean
example [Monoid α] (a : α) (m n : Nat) : a ^ (m + n) = a ^ m * a ^ n := pow_add a m n
```

### `pow_mul`
Power of a power: `a ^ (m * n) = (a ^ m) ^ n`
```lean
example [Monoid α] (a : α) (m n : Nat) : a ^ (m * n) = (a ^ m) ^ n := pow_mul a m n
```

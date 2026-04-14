# Ring & Field Operations

[Back to Index](../index.md)

Distributivity, division, and related lemmas for rings and fields.

---

### `left_distrib` / `mul_add`
Left distributivity in a ring: `a * (b + c) = a * b + a * c`
```lean
example [Ring α] (a b c : α) : a * (b + c) = a * b + a * c := left_distrib a b c
```

### `right_distrib` / `add_mul`
Right distributivity in a ring: `(a + b) * c = a * c + b * c`
```lean
example [Ring α] (a b c : α) : (a + b) * c = a * c + b * c := right_distrib a b c
```

### `sq_nonneg`
The square of any element in a linear ordered ring is non-negative.
```lean
example [LinearOrderedRing α] (a : α) : 0 ≤ a ^ 2 := sq_nonneg a
```

### `div_add_div_same`
Adding fractions with the same denominator: `a/c + b/c = (a+b)/c`
```lean
example [Field α] (a b c : α) : a / c + b / c = (a + b) / c := div_add_div_same a b c
```

### `div_self`
A nonzero value divided by itself is one.
```lean
example [Field α] (a : α) (h : a ≠ 0) : a / a = 1 := div_self h
```

### `mul_div_cancel`
Multiplying and dividing by the same value cancels.
```lean
example [Field α] (a : α) {b : α} (h : b ≠ 0) : a * b / b = a := mul_div_cancel₀ a h
```

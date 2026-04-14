# Integer Arithmetic

[Back to Index](../index.md)

Lemmas for integer addition, multiplication, negation, and absolute value.

---

### `Int.add_comm`
Commutativity of integer addition.
```lean
example (a b : Int) : a + b = b + a := Int.add_comm a b
```

### `Int.add_assoc`
Associativity of integer addition.
```lean
example (a b c : Int) : a + b + c = a + (b + c) := Int.add_assoc a b c
```

### `Int.mul_comm`
Commutativity of integer multiplication.
```lean
example (a b : Int) : a * b = b * a := Int.mul_comm a b
```

### `Int.neg_add_cancel` / `Int.add_left_neg`
Adding a number and its negation: `-a + a = 0`
```lean
example (a : Int) : -a + a = 0 := Int.neg_add_cancel a
```

### `Int.mul_neg`
Multiplication by a negative: `a * (-b) = -(a * b)`
```lean
example (a b : Int) : a * (-b) = -(a * b) := Int.mul_neg a b
```

### `Int.neg_mul`
Negative times positive: `(-a) * b = -(a * b)`
```lean
example (a b : Int) : (-a) * b = -(a * b) := Int.neg_mul a b
```

### `Int.neg_neg`
Double negation: `-(-a) = a`
```lean
example (a : Int) : -(-a) = a := Int.neg_neg a
```

### `Int.abs_nonneg`
Absolute value is non-negative.
```lean
example (a : Int) : 0 ≤ |a| := abs_nonneg a
```

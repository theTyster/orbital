# Natural Number Arithmetic

[Back to Index](../index.md)

Core lemmas for addition and multiplication of natural numbers.

---

### `Nat.add_comm`
Commutativity of natural number addition: `a + b = b + a`
```lean
example (a b : Nat) : a + b = b + a := Nat.add_comm a b
```

### `Nat.add_assoc`
Associativity of natural number addition: `(a + b) + c = a + (b + c)`
```lean
example (a b c : Nat) : (a + b) + c = a + (b + c) := Nat.add_assoc a b c
```

### `Nat.mul_comm`
Commutativity of natural number multiplication: `a * b = b * a`
```lean
example (a b : Nat) : a * b = b * a := Nat.mul_comm a b
```

### `Nat.mul_assoc`
Associativity of multiplication: `(a * b) * c = a * (b * c)`
```lean
example (a b c : Nat) : (a * b) * c = a * (b * c) := Nat.mul_assoc a b c
```

### `Nat.left_distrib` / `Nat.mul_add`
Left distributivity: `a * (b + c) = a * b + a * c`
```lean
example (a b c : Nat) : a * (b + c) = a * b + a * c := Nat.left_distrib a b c
```

### `Nat.right_distrib` / `Nat.add_mul`
Right distributivity: `(a + b) * c = a * c + b * c`
```lean
example (a b c : Nat) : (a + b) * c = a * c + b * c := Nat.right_distrib a b c
```

### `Nat.zero_add`
Zero is a left identity for addition: `0 + a = a`
```lean
example (a : Nat) : 0 + a = a := Nat.zero_add a
```

### `Nat.add_zero`
Zero is a right identity for addition: `a + 0 = a`
```lean
example (a : Nat) : a + 0 = a := Nat.add_zero a
```

### `Nat.one_mul`
One is a left identity for multiplication: `1 * a = a`
```lean
example (a : Nat) : 1 * a = a := Nat.one_mul a
```

### `Nat.mul_one`
One is a right identity for multiplication: `a * 1 = a`
```lean
example (a : Nat) : a * 1 = a := Nat.mul_one a
```

### `Nat.zero_mul`
Zero annihilates on the left: `0 * a = 0`
```lean
example (a : Nat) : 0 * a = 0 := Nat.zero_mul a
```

### `Nat.mul_zero`
Zero annihilates on the right: `a * 0 = 0`
```lean
example (a : Nat) : a * 0 = 0 := Nat.mul_zero a
```

### `Nat.succ_add`
Successor distributes over addition on the left: `succ a + b = succ (a + b)`
```lean
example (a b : Nat) : Nat.succ a + b = Nat.succ (a + b) := Nat.succ_add a b
```

### `Nat.add_succ`
Adding a successor on the right: `a + succ b = succ (a + b)`
```lean
example (a b : Nat) : a + Nat.succ b = Nat.succ (a + b) := Nat.add_succ a b
```

### `Nat.sub_self`
Subtracting a number from itself yields zero: `a - a = 0`
```lean
example (a : Nat) : a - a = 0 := Nat.sub_self a
```

### `Nat.add_sub_cancel`
Adding then subtracting cancels: `a + b - b = a`
```lean
example (a b : Nat) : a + b - b = a := Nat.add_sub_cancel
```

---

## See also

- [Additive Structures](additive-structures.md) -- generic versions of commutativity, associativity, and identity lemmas for any `AddCommMonoid`
- [Multiplicative Structures](multiplicative-structures.md) -- generic multiplicative analogues
- [Natural Number Ordering](nat-ordering.md) -- ordering lemmas on `Nat`
- [Natural Number Divisibility](nat-divisibility.md) -- divisibility and GCD on `Nat`

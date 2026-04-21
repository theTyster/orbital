# Natural Number Divisibility

[Back to Index](../index.md)

Lemmas for divisibility, modular arithmetic, and GCD on natural numbers.

---

### `Nat.dvd_refl`
Every number divides itself.
```lean
example (a : Nat) : a ∣ a := Nat.dvd_refl a
```

### `Nat.dvd_trans`
Divisibility is transitive.
```lean
example (a b c : Nat) (h1 : a ∣ b) (h2 : b ∣ c) : a ∣ c := Nat.dvd_trans h1 h2
```

### `Nat.dvd_add`
If `a ∣ b` and `a ∣ c`, then `a ∣ b + c`.
```lean
example (a b c : Nat) (h1 : a ∣ b) (h2 : a ∣ c) : a ∣ (b + c) := Nat.dvd_add h1 h2
```

### `Nat.mod_self`
A number mod itself is zero.
```lean
example (a : Nat) : a % a = 0 := Nat.mod_self a
```

### `Nat.mod_lt`
The remainder is less than the divisor (when divisor > 0).
```lean
example (a : Nat) (b : Nat) (h : 0 < b) : a % b < b := Nat.mod_lt a h
```

### `Nat.div_add_mod`
Division-remainder identity: `b * (a / b) + a % b = a`
```lean
example (a b : Nat) : b * (a / b) + a % b = a := Nat.div_add_mod a b
```

### `Nat.gcd_comm`
GCD is commutative.
```lean
example (a b : Nat) : Nat.gcd a b = Nat.gcd b a := Nat.gcd_comm a b
```

### `Nat.gcd_assoc`
GCD is associative.
```lean
example (a b c : Nat) : Nat.gcd (Nat.gcd a b) c = Nat.gcd a (Nat.gcd b c) :=
  Nat.gcd_assoc a b c
```

### `Nat.gcd_dvd_left`
The GCD divides the first argument.
```lean
example (a b : Nat) : Nat.gcd a b ∣ a := Nat.gcd_dvd_left a b
```

### `Nat.gcd_dvd_right`
The GCD divides the second argument.
```lean
example (a b : Nat) : Nat.gcd a b ∣ b := Nat.gcd_dvd_right a b
```

---

## See also

- [Primes & Divisibility](../theorems/primes-divisibility.md) -- prime factorization theorems and general divisibility results
- [Modular Arithmetic](../theorems/modular-arithmetic.md) -- `ZMod` and congruence theorems
- [Natural Number Arithmetic](nat-arithmetic.md) -- basic `Nat` addition and multiplication

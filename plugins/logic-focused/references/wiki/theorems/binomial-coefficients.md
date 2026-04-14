# Binomial Coefficients

[Back to Index](../index.md)

Binomial theorem, Pascal's rule, Vandermonde's identity, and symmetry.

---

### `add_pow`
**Binomial theorem**: `(a + b)^n = ∑ C(n,k) * a^k * b^(n-k)`.
```lean
example [CommSemiring R] (a b : R) (n : Nat) :
    (a + b) ^ n = ∑ k in Finset.range (n + 1), n.choose k * a ^ k * b ^ (n - k) :=
  add_pow a b n
```

### `Nat.choose_succ_succ`
**Pascal's rule**: `C(n+1, k+1) = C(n, k) + C(n, k+1)`.
```lean
example (n k : Nat) : (n + 1).choose (k + 1) = n.choose k + n.choose (k + 1) :=
  Nat.choose_succ_succ n k
```

### `Nat.choose_symm`
Symmetry of binomial coefficients: `C(n, k) = C(n, n-k)`.
```lean
example (n k : Nat) (h : k ≤ n) : n.choose k = n.choose (n - k) := Nat.choose_symm h
```

### `Finset.card_powersetCard`
**Binomial coefficient**: `|{S ⊆ Fin n | |S| = k}| = C(n, k)`.
```lean
example [DecidableEq α] (s : Finset α) (k : Nat) :
    (Finset.powersetCard k s).card = s.card.choose k :=
  Finset.card_powersetCard k s
```

### `Nat.add_choose_eq`
**Vandermonde's identity**: `C(m+n, r) = ∑ C(m,k) * C(n, r-k)`.
```lean
-- Formalized in Mathlib.Combinatorics.Choose
```

# Primes & Divisibility

[Back to Index](../index.md)

Fundamental theorems about prime numbers, divisibility, and unique factorization.

---

### `Nat.Prime.eq_one_or_self_of_dvd`
**Fundamental property of primes**: if `p` is prime and `d ∣ p`, then `d = 1` or `d = p`.
```lean
example (p d : Nat) (hp : Nat.Prime p) (hd : d ∣ p) : d = 1 ∨ d = p :=
  hp.eq_one_or_self_of_dvd d hd
```

### `Nat.exists_infinite_primes`
**Euclid's theorem**: there are infinitely many primes. For any `n`, there exists a prime `p ≥ n`.
```lean
example (n : Nat) : ∃ p, n ≤ p ∧ Nat.Prime p := Nat.exists_infinite_primes n
```

### `Nat.Prime.dvd_mul`
**Euclid's lemma**: if a prime divides a product, it divides one of the factors.
```lean
example (p a b : Nat) (hp : Nat.Prime p) (h : p ∣ a * b) : p ∣ a ∨ p ∣ b :=
  hp.dvd_mul.mp h
```

### `UniqueFactorizationMonoid`
**Fundamental Theorem of Arithmetic**: every natural number > 1 has a unique prime factorization. Nat is an instance of `UniqueFactorizationMonoid`.
```lean
example : UniqueFactorizationMonoid Nat := inferInstance
```

### `Nat.Prime.minFac_eq`
Every composite number has a prime factor found by `minFac`.
```lean
example (n : Nat) (h : Nat.Prime n) : n.minFac = n := h.minFac_eq
```

### `Nat.Coprime.mul_dvd_of_dvd_of_dvd`
If `gcd(a,b) = 1` and `a ∣ n` and `b ∣ n`, then `a*b ∣ n`.
```lean
example (a b n : Nat) (h : Nat.Coprime a b) (ha : a ∣ n) (hb : b ∣ n) : a * b ∣ n :=
  h.mul_dvd_of_dvd_of_dvd ha hb
```

### `Polynomial.card_roots_le_degree`
A polynomial of degree `n` has at most `n` roots.
```lean
example [CommRing R] [IsDomain R] (p : Polynomial R) (hp : p ≠ 0) :
    Multiset.card p.roots ≤ p.natDegree := Polynomial.card_roots_le_degree p
```

### `IsPrincipalIdealRing`
**Structure theorem**: every Euclidean domain is a PID.
```lean
example [EuclideanDomain R] : IsPrincipalIdealRing R := inferInstance
```

### `EuclideanDomain.div_add_mod`
**Division algorithm** (general Euclidean domains): `a = q * b + r`.
```lean
example [EuclideanDomain R] (a b : R) : b * (a / b) + a % b = a :=
  EuclideanDomain.div_add_mod a b
```

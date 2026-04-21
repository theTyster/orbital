# Modular Arithmetic

[Back to Index](../index.md)

Chinese Remainder Theorem, Fermat's little theorem, Euler's theorem, and Wilson's theorem.

---

### `ZMod.chineseRemainder`
**Chinese Remainder Theorem** (isomorphism form): `ZMod (m * n) ≃+* ZMod m × ZMod n` when `m` and `n` are coprime.
```lean
example (m n : Nat) (h : Nat.Coprime m n) : ZMod (m * n) ≃+* ZMod m × ZMod n :=
  ZMod.chineseRemainder h
```

### `Int.emod_emod_of_dvd`
**Chinese Remainder Theorem** (computational form): relates nested modular reductions when one modulus divides the other.
```lean
example (a b c : Int) (h : b ∣ c) : a % c % b = a % b := Int.emod_emod_of_dvd a h
```

### `ZMod.card_units_eq_totient`
**Euler's totient**: the number of units in `ZMod n` equals `φ(n)`.
```lean
example (n : Nat) [NeZero n] : Fintype.card (ZMod n)ˣ = Nat.totient n :=
  ZMod.card_units_eq_totient n
```

### `ZMod.units_pow_card_sub_one_eq_one`
**Fermat's Little Theorem**: `a^(p-1) ≡ 1 (mod p)` for prime `p` and `gcd(a,p) = 1`.
```lean
example (p : Nat) [Fact (Nat.Prime p)] (a : (ZMod p)ˣ) : a ^ (p - 1) = 1 :=
  ZMod.units_pow_card_sub_one_eq_one a
```

### `ZMod.pow_totient`
**Euler's theorem**: `a^φ(n) ≡ 1 (mod n)` when `gcd(a,n) = 1`.
```lean
example (n : Nat) [NeZero n] (a : (ZMod n)ˣ) : a ^ Nat.totient n = 1 :=
  ZMod.pow_totient a
```

### `Nat.Prime.Wilson`
**Wilson's theorem**: `p` is prime iff `(p-1)! ≡ -1 (mod p)`.
```lean
-- Nat.Prime.factorial_mulInv_atFin_prime or similar formulation
```

---

## See also

- [Primes & Divisibility](primes-divisibility.md) -- Euclid's lemma, unique factorization, division algorithm
- [Group Theory](group-theory.md) -- Lagrange's theorem and Sylow theorems (units of ZMod form a group)

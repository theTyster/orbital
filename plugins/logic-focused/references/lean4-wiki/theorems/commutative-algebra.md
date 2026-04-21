# Commutative Algebra

[Back to Index](../index.md)

Maximal and prime ideals, Nakayama's lemma, and localization.

---

### `Ideal.IsMaximal.isPrime`
Every maximal ideal is prime.
```lean
example [CommRing R] {I : Ideal R} (hI : I.IsMaximal) : I.IsPrime := hI.isPrime
```

### `Ideal.Quotient.maximal_of_isField`
An ideal is maximal iff the quotient ring is a field.
```lean
-- Ideal.Quotient.maximal_ideal_iff_isField_quotient
```

### `LocalRing`
**Nakayama's lemma**: formalized for local rings and finitely generated modules.
```lean
-- Submodule.eq_bot_of_le_smul_of_le_jacobson_bot or similar
```

### `IsLocalization`
**Universal property of localization**: `S⁻¹R` is characterized by a universal property.
```lean
-- IsLocalization in Mathlib.RingTheory.Localization
```

### `PrimeSpectrum.zeroLocus_vanishingIdeal`
**Nullstellensatz** connection: Zariski topology relates ideals and algebraic sets.
```lean
-- Formalized in Mathlib.AlgebraicGeometry.PrimeSpectrum
```

### `Polynomial.isUnit_iff`
A polynomial over a domain is a unit iff it's a nonzero constant.
```lean
-- Polynomial.isUnit_iff for integral domains
```

---

## See also

- [Ring & Polynomial Theory](ring-polynomial-theory.md) -- Hilbert's basis theorem, Cayley-Hamilton, polynomial division
- [Field & Galois Theory](field-galois-theory.md) -- splitting fields, Galois theory, algebraic closure

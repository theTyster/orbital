# Famous Results

[Back to Index](../index.md)

Miscellaneous famous mathematical results formalized in Mathlib.

---

### `irrational_sqrt_two`
**Irrationality of √2**.
```lean
example : Irrational (Real.sqrt 2) := irrational_sqrt_two
```

### `Complex.exp_mul_I`
**Euler's formula**: `exp(ix) = cos(x) + i*sin(x)`.
```lean
example (x : ℝ) : Complex.exp (x * Complex.I) = Complex.cos x + Complex.sin x * Complex.I :=
  sorry -- Complex.exp_mul_I or derived from it
```

### `Complex.exp_eq_exp_iff_exists_int`
**Periodicity of complex exponential**: `exp(z) = exp(w)` iff `z - w = 2πin` for some integer `n`.
```lean
-- Complex.exp_eq_exp_iff_exists_int
```

### `Equiv.Perm.sign_mul`
**Sign of a permutation composition**: `sign(σ ∘ τ) = sign(σ) * sign(τ)`.
```lean
example [DecidableEq α] [Fintype α] (σ τ : Equiv.Perm α) :
    Equiv.Perm.sign (σ * τ) = Equiv.Perm.sign σ * Equiv.Perm.sign τ :=
  map_mul Equiv.Perm.sign σ τ
```

### `MvPolynomial.symmetric`
**Fundamental Theorem of Symmetric Polynomials**: every symmetric polynomial is a polynomial in the elementary symmetric polynomials.
```lean
-- Formalized in Mathlib.RingTheory.MvPolynomial.Symmetric
```

### `Finset.prod_dvd_prod_of_dvd`
If `f i ∣ g i` for each `i`, then `∏ f ∣ ∏ g`.
```lean
example [CommMonoid α] (s : Finset ι) (f g : ι → α) (h : ∀ i ∈ s, f i ∣ g i) :
    ∏ i in s, f i ∣ ∏ i in s, g i := Finset.prod_dvd_prod_of_dvd s h
```

### Stirling's Approximation
**Stirling's approximation**: `n! ~ √(2πn) * (n/e)^n`.
```lean
-- Partial formalization in Mathlib.Analysis.SpecificLimits.Stirling or similar
```

### `Finset.sum_ite_eq`
**Kronecker delta** summation: `∑ᵢ (if i = j then f i else 0) = f j`.
```lean
example [DecidableEq α] [AddCommMonoid β] (s : Finset α) (j : α) (f : α → β) (hj : j ∈ s) :
    ∑ i in s, (if i = j then f i else 0) = f j := by
  simp [Finset.sum_ite_eq, hj]
```

### `CategoryTheory.Yoneda.fullyFaithful`
**Yoneda Lemma**: the Yoneda embedding is fully faithful.
```lean
example [CategoryTheory.Category C] : CategoryTheory.Functor.FullyFaithful
    (CategoryTheory.yoneda : C ⥤ Cᵒᵖ ⥤ Type _) :=
  CategoryTheory.Yoneda.fullyFaithful
```

### `CategoryTheory.Adjunction.homEquiv`
**Adjunction**: `Hom(F a, b) ≃ Hom(a, G b)` naturally.
```lean
example [CategoryTheory.Category C] [CategoryTheory.Category D]
    {F : CategoryTheory.Functor C D} {G : CategoryTheory.Functor D C}
    (adj : F ⊣ G) (a : C) (b : D) : (F.obj a ⟶ b) ≃ (a ⟶ G.obj b) :=
  adj.homEquiv a b
```

# Ring & Polynomial Theory

[Back to Index](../index.md)

Hilbert's basis theorem, polynomial division, Cayley-Hamilton, and the Fundamental Theorem of Algebra.

---

### `Polynomial.aeval_algebraMap_apply` / `Matrix.aeval_self_charpoly`
**Cayley-Hamilton Theorem**: every square matrix satisfies its own characteristic polynomial.
```lean
example [CommRing R] [Fintype n] [DecidableEq n] (M : Matrix n n R) :
    Polynomial.aeval M M.charpoly = 0 := M.aeval_self_charpoly
```

### `IsNoetherian`
**Hilbert's Basis Theorem**: if `R` is Noetherian, then `R[X]` is Noetherian.
```lean
example [CommRing R] [IsNoetherianRing R] : IsNoetherianRing (Polynomial R) := inferInstance
```

### `MvPolynomial.isNoetherianRing`
**Hilbert's Basis Theorem** (multivariate): `R[X₁,...,Xₙ]` is Noetherian when `R` is.
```lean
example [CommRing R] [IsNoetherianRing R] [Fintype σ] :
    IsNoetherianRing (MvPolynomial σ R) := inferInstance
```

### `IsAlgClosed.exists_root`
**Fundamental Theorem of Algebra**: every non-constant polynomial over `ℂ` has a root.
```lean
example (p : Polynomial ℂ) (hp : 0 < p.degree) : ∃ z, p.IsRoot z :=
  IsAlgClosed.exists_root p (ne_of_gt hp)
```

### `Complex.isAlgClosed`
`ℂ` is algebraically closed.
```lean
example : IsAlgClosed ℂ := Complex.isAlgClosed
```

### `Polynomial.div_by_monic_add_mod`
**Polynomial division algorithm**: `p = (p /ₘ q) * q + (p %ₘ q)`.
```lean
example [CommRing R] (p q : Polynomial R) (hq : q.Monic) :
    p %ₘ q + q * (p /ₘ q) = p := Polynomial.modByMonic_add_div p hq
```

### `Ideal.quotientKerEquivRange`
**First Isomorphism Theorem** (for rings): `R / ker(f) ≅ im(f)`.
```lean
example [CommRing R] [CommRing S] (f : R →+* S) :
    R ⧸ RingHom.ker f ≃+* RingHom.range f :=
  RingHom.quotientKerEquivRange f
```

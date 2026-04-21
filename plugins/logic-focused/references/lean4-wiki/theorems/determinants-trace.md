# Determinants & Trace

[Back to Index](../index.md)

Multiplicativity of determinants, transpose, and trace cyclicity.

---

### `Matrix.det_mul`
**Multiplicativity of determinant**: `det(AB) = det(A) * det(B)`.
```lean
example [CommRing R] [Fintype n] [DecidableEq n] (A B : Matrix n n R) :
    (A * B).det = A.det * B.det := Matrix.det_mul A B
```

### `Matrix.det_transpose`
`det(Aᵀ) = det(A)`.
```lean
example [CommRing R] [Fintype n] [DecidableEq n] (A : Matrix n n R) :
    Aᵀ.det = A.det := Matrix.det_transpose A
```

### `Matrix.det_one`
`det(I) = 1`.
```lean
example [CommRing R] [Fintype n] [DecidableEq n] : (1 : Matrix n n R).det = 1 := Matrix.det_one
```

### `Matrix.nonsing_inv_mul`
A matrix times its inverse is the identity (when det ≠ 0).
```lean
example [CommRing R] [Fintype n] [DecidableEq n] (A : Matrix n n R) (h : A.det ≠ 0) :
    A⁻¹ * A = 1 := sorry -- Matrix.nonsing_inv_mul A (isUnit_of_det_ne_zero h)
```

### `Matrix.trace_mul_comm`
**Trace is cyclic**: `tr(AB) = tr(BA)`.
```lean
example [CommRing R] [Fintype n] [DecidableEq n] (A B : Matrix n n R) :
    (A * B).trace = (B * A).trace := Matrix.trace_mul_comm A B
```

### `Matrix.det_zero`
**Determinant of the zero matrix**: `det(0) = 0` (when the index type is nonempty).
```lean
example [CommRing R] [Fintype n] [DecidableEq n] [Nonempty n] :
    (0 : Matrix n n R).det = 0 := Matrix.det_zero n R
```

### `Matrix.det_neg`
**Determinant of negation**: `det(-A) = (-1)^n * det(A)`.
```lean
example [CommRing R] [Fintype n] [DecidableEq n] (A : Matrix n n R) :
    (-A).det = (-1) ^ Fintype.card n * A.det := Matrix.det_neg A
```

---

## See also

- [Linear Algebra Fundamentals](linear-algebra-fundamentals.md) -- rank-nullity, bases, spectral theorem
- [Linear Maps](../lemmas/linear-maps.md) -- kernel, range, and preservation properties of linear maps

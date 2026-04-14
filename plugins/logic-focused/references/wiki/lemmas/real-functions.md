# Real Functions

[Back to Index](../index.md)

Identities for square root, exponential, and logarithm on the reals.

---

### `Real.sqrt_sq`
Square root of a square (for non-negative): `√(a²) = a` when `0 ≤ a`
```lean
example (a : Real) (h : 0 ≤ a) : Real.sqrt (a ^ 2) = a := Real.sqrt_sq h
```

### `Real.exp_add`
Exponential of a sum: `exp(a + b) = exp(a) * exp(b)`
```lean
example (a b : Real) : Real.exp (a + b) = Real.exp a * Real.exp b := Real.exp_add a b
```

### `Real.exp_zero`
Exponential of zero: `exp(0) = 1`
```lean
example : Real.exp 0 = 1 := Real.exp_zero
```

### `Real.log_mul`
Logarithm of a product: `log(a * b) = log(a) + log(b)` (for nonzero arguments).
```lean
example (a b : Real) (ha : a ≠ 0) (hb : b ≠ 0) :
    Real.log (a * b) = Real.log a + Real.log b := Real.log_mul ha hb
```

### `Real.log_exp`
Log and exp are inverses: `log(exp(a)) = a`
```lean
example (a : Real) : Real.log (Real.exp a) = a := Real.log_exp a
```

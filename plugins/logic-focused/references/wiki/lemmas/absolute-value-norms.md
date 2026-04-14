# Absolute Value & Norms

[Back to Index](../index.md)

Lemmas for absolute value and norm operations.

---

### `abs_nonneg`
Absolute value is non-negative.
```lean
example (a : Real) : 0 ≤ |a| := abs_nonneg a
```

### `abs_add`
Triangle inequality: `|a + b| ≤ |a| + |b|`
```lean
example (a b : Real) : |a + b| ≤ |a| + |b| := abs_add a b
```

### `abs_mul`
Absolute value of a product: `|a * b| = |a| * |b|`
```lean
example (a b : Real) : |a * b| = |a| * |b| := abs_mul a b
```

### `abs_sub_comm`
Symmetry of absolute difference: `|a - b| = |b - a|`
```lean
example (a b : Real) : |a - b| = |b - a| := abs_sub_comm a b
```

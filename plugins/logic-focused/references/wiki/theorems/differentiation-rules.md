# Differentiation Rules

[Back to Index](../index.md)

Sum rule, product rule, chain rule, quotient rule, and power rule.

---

### `HasDerivAt.add`
**Sum rule**: `(f + g)' = f' + g'`.
```lean
example {f g : ℝ → ℝ} {f' g' x : ℝ} (hf : HasDerivAt f f' x) (hg : HasDerivAt g g' x) :
    HasDerivAt (f + g) (f' + g') x := hf.add hg
```

### `HasDerivAt.mul`
**Product rule**: `(f * g)' = f' * g + f * g'`.
```lean
example {f g : ℝ → ℝ} {f' g' x : ℝ} (hf : HasDerivAt f f' x) (hg : HasDerivAt g g' x) :
    HasDerivAt (fun x => f x * g x) (f' * g x + f x * g') x := hf.mul hg
```

### `HasDerivAt.comp`
**Chain rule**: `(f ∘ g)'(x) = f'(g(x)) * g'(x)`.
```lean
example {f : ℝ → ℝ} {g : ℝ → ℝ} {f' g' x : ℝ}
    (hf : HasDerivAt f f' (g x)) (hg : HasDerivAt g g' x) :
    HasDerivAt (f ∘ g) (f' * g') x := HasDerivAt.comp x hf hg
```

### `HasDerivAt.div`
**Quotient rule**: `(f/g)' = (f'g - fg') / g²`.
```lean
example {f g : ℝ → ℝ} {f' g' x : ℝ} (hf : HasDerivAt f f' x) (hg : HasDerivAt g g' x)
    (hg0 : g x ≠ 0) :
    HasDerivAt (fun x => f x / g x) ((f' * g x - f x * g') / g x ^ 2) x :=
  hf.div hg hg0
```

### `hasDerivAt_pow`
**Power rule**: `(x^n)' = n * x^(n-1)`.
```lean
example (n : Nat) (x : ℝ) : HasDerivAt (fun x => x ^ n) (n * x ^ (n - 1)) x :=
  hasDerivAt_pow n x
```

### `HasFDerivAt.comp`
**Chain rule** (multivariate / Frechet derivative form).
```lean
example [NormedAddCommGroup E] [NormedSpace ℝ E] [NormedAddCommGroup F] [NormedSpace ℝ F]
    [NormedAddCommGroup G] [NormedSpace ℝ G]
    {f : F → G} {g : E → F} {f' : F →L[ℝ] G} {g' : E →L[ℝ] F} {x : E}
    (hf : HasFDerivAt f f' (g x)) (hg : HasFDerivAt g g' x) :
    HasFDerivAt (f ∘ g) (f'.comp g') x := hf.comp x hg
```

---

## See also

- [Standard Derivatives](standard-derivatives.md) -- derivatives of specific functions (exp, log, sin, cos, etc.)
- [Mean Value Theorems](mean-value-theorems.md) -- MVT, Rolle's theorem, and L'Hopital's rule

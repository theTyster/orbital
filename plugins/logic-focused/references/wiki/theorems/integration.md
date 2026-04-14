# Integration

[Back to Index](../index.md)

Linearity of integration, Fundamental Theorem of Calculus, and convergence theorems.

---

### `MeasureTheory.integral_add`
**Linearity of integration**: `∫ (f + g) = ∫ f + ∫ g`.
```lean
example [MeasureSpace α] [NormedAddCommGroup E] [NormedSpace ℝ E]
    {f g : α → E} (hf : Integrable f) (hg : Integrable g) :
    ∫ x, f x + g x = ∫ x, f x + ∫ x, g x := integral_add hf hg
```

### `MeasureTheory.integral_smul`
**Scalar multiplication passes through integrals**: `∫ c • f = c • ∫ f`.
```lean
example [MeasureSpace α] [NormedAddCommGroup E] [NormedSpace ℝ E] (c : ℝ) (f : α → E) :
    ∫ x, c • f x = c • ∫ x, f x := integral_smul c f
```

### `intervalIntegral.integral_eq_sub_of_hasDerivAt`
**Fundamental Theorem of Calculus** (part 2): `∫_a^b f'(x) dx = f(b) - f(a)`.
```lean
example {f f' : ℝ → ℝ} {a b : ℝ}
    (hf : ∀ x ∈ Set.Icc a b, HasDerivAt f (f' x) x)
    (hf' : IntervalIntegrable f' MeasureTheory.volume a b) :
    ∫ x in a..b, f' x = f b - f a :=
  intervalIntegral.integral_eq_sub_of_hasDerivAt (sorry) hf'
```

### `intervalIntegral.integral_add_adjacent_intervals`
**Additivity of integrals over intervals**: `∫_a^b f + ∫_b^c f = ∫_a^c f`.
```lean
example {f : ℝ → ℝ} {a b c : ℝ}
    (hab : IntervalIntegrable f MeasureTheory.volume a b)
    (hbc : IntervalIntegrable f MeasureTheory.volume b c) :
    ∫ x in a..b, f x + ∫ x in b..c, f x = ∫ x in a..c, f x :=
  intervalIntegral.integral_add_adjacent_intervals hab hbc
```

### `MeasureTheory.integral_nonneg`
If `f ≥ 0` a.e., then `∫ f ≥ 0`.
```lean
example [MeasureSpace α] {f : α → ℝ} (hf : ∀ x, 0 ≤ f x) :
    0 ≤ ∫ x, f x := integral_nonneg hf
```

### `MeasureTheory.norm_integral_le_integral_norm`
**Triangle inequality for integrals**: `‖∫ f‖ ≤ ∫ ‖f‖`.
```lean
example [MeasureSpace α] [NormedAddCommGroup E] [NormedSpace ℝ E] (f : α → E) :
    ‖∫ x, f x‖ ≤ ∫ x, ‖f x‖ := norm_integral_le_integral_norm f
```

### `MeasureTheory.lintegral_iSup`
**Monotone Convergence Theorem** (Lebesgue): the integral of a sup of an increasing sequence equals the sup of the integrals.
```lean
-- lintegral_iSup for monotone sequences of measurable functions
```

### `MeasureTheory.tendsto_integral_of_dominated_convergence`
**Dominated Convergence Theorem**: if `fₙ → f` pointwise and `|fₙ| ≤ g` with `g` integrable, then `∫ fₙ → ∫ f`.
```lean
-- MeasureTheory.tendsto_integral_of_dominated_convergence
```

### `MeasureTheory.lintegral_mono`
Monotone convergence for Lebesgue integrals.
```lean
example [MeasurableSpace α] {μ : MeasureTheory.Measure α} {f g : α → ENNReal}
    (h : ∀ x, f x ≤ g x) : ∫⁻ x, f x ∂μ ≤ ∫⁻ x, g x ∂μ :=
  MeasureTheory.lintegral_mono h
```

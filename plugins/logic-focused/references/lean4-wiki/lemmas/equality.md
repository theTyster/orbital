# Equality

[Back to Index](../index.md)

Lemmas for equality, congruence, and extensionality.

---

### `Eq.symm`
Symmetry of equality.
```lean
example (h : a = b) : b = a := h.symm
```

### `Eq.trans`
Transitivity of equality.
```lean
example (h1 : a = b) (h2 : b = c) : a = c := h1.trans h2
```

### `congrArg`
If `a = b` then `f a = f b`.
```lean
example (f : α → β) (h : a = b) : f a = f b := congrArg f h
```

### `funext`
Function extensionality: if `∀ x, f x = g x` then `f = g`.
```lean
example (f g : α → β) (h : ∀ x, f x = g x) : f = g := funext h
```

### `propext`
Propositional extensionality: if `P ↔ Q` then `P = Q`.
```lean
example (h : P ↔ Q) : P = Q := propext h
```

---

## See also

- [Connectives](connectives.md) — logical And, Or, Iff introduction and elimination
- [Quantifiers & Classical Logic](quantifiers-classical.md) — existential witnesses, excluded middle, and contradiction

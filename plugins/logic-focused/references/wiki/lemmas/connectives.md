# Connectives

[Back to Index](../index.md)

Introduction and elimination rules for logical connectives: And, Or, Iff.

---

### `And.intro`
Introduction rule for conjunction.
```lean
example (hp : P) (hq : Q) : P ∧ Q := And.intro hp hq
```

### `And.left` / `And.right`
Elimination rules for conjunction.
```lean
example (h : P ∧ Q) : P := h.left
example (h : P ∧ Q) : Q := h.right
```

### `Or.inl` / `Or.inr`
Introduction rules for disjunction.
```lean
example (hp : P) : P ∨ Q := Or.inl hp
example (hq : Q) : P ∨ Q := Or.inr hq
```

### `Or.elim`
Elimination rule for disjunction (case split).
```lean
example (h : P ∨ Q) (hp : P → R) (hq : Q → R) : R := Or.elim h hp hq
```

### `Iff.intro`
Build an if-and-only-if from both directions.
```lean
example (hpq : P → Q) (hqp : Q → P) : P ↔ Q := Iff.intro hpq hqp
```

### `Iff.mp` / `Iff.mpr`
Extract the forward/backward direction of an iff.
```lean
example (h : P ↔ Q) (hp : P) : Q := h.mp hp
example (h : P ↔ Q) (hq : Q) : P := h.mpr hq
```

# Quantifiers & Classical Logic

[Back to Index](../index.md)

Existential quantifiers, double negation, excluded middle, contradiction, and ex falso.

---

### `Exists.intro`
Existential introduction.
```lean
example : ∃ n : Nat, n > 0 := ⟨1, Nat.one_pos⟩
```

### `Exists.choose`
Extract a witness from an existential (uses choice).
```lean
example (h : ∃ n : Nat, n > 0) : Nat := h.choose
```

### `not_not`
Double negation elimination (classical): `¬¬P ↔ P`
```lean
example [Decidable P] (h : ¬¬P) : P := not_not.mp h
```

### `Classical.em`
Law of excluded middle: `P ∨ ¬P`
```lean
example (P : Prop) : P ∨ ¬P := Classical.em P
```

### `Classical.byContradiction`
Proof by contradiction: if `¬P → False` then `P`.
```lean
example : P := Classical.byContradiction fun h => absurd hp h
```

### `absurd`
From `P` and `¬P`, derive anything.
```lean
example (hp : P) (hnp : ¬P) : Q := absurd hp hnp
```

### `False.elim`
Ex falso quodlibet: from `False`, derive anything.
```lean
example (h : False) : P := False.elim h
```

### `Decidable.not_not`
Constructive double negation elimination for decidable propositions.
```lean
example [Decidable P] (h : ¬¬P) : P := Decidable.not_not.mp h
```

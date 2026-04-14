# Foundations

[Back to Index](../index.md)

Zorn's lemma, axiom of choice, well-ordering, and transfinite induction.

---

### `zorn_partialOrder`
**Zorn's Lemma**: if every chain has an upper bound, there exists a maximal element.
```lean
example [PartialOrder α] [Nonempty α]
    (h : ∀ c : Set α, IsChain (· ≤ ·) c → BddAbove c) :
    ∃ m : α, ∀ a, m ≤ a → a = m := zorn_partialOrder h
```

### `Classical.choice`
**Axiom of Choice**: every nonempty type has an element (built into Lean's foundation).
```lean
example (h : Nonempty α) : α := Classical.choice h
```

### `WellFounded.recursion`
**Well-ordering principle / transfinite induction**: every well-founded relation supports recursion.
```lean
example [WellFoundedRelation α] : WellFounded (· < · : α → α → Prop) := sorry
```

### `Set.Finite.of_surjOn`
If there's a surjection from a finite set onto `B`, then `B` is finite.
```lean
-- Set.Finite.of_surjOn
```

---

## See also

- [Cardinality](cardinality.md) -- Cantor's theorem, Cantor-Bernstein-Schroeder
- [Quantifiers & Classical Logic](../lemmas/quantifiers-classical.md) -- classical reasoning, decidability, De Morgan's laws

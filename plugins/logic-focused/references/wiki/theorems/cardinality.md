# Cardinality

[Back to Index](../index.md)

Cantor's theorem, Cantor-Bernstein-Schroeder, and injection/surjection bounds.

---

### `Cardinal.cantor`
**Cantor's theorem**: `|A| < |𝒫(A)|` — no surjection from a set to its power set.
```lean
example (α : Type*) : Cardinal.mk α < Cardinal.mk (Set α) := Cardinal.cantor α
```

### `Function.Embedding.antisymm`
**Cantor-Bernstein-Schroeder**: if `|A| ≤ |B|` and `|B| ≤ |A|` then `|A| = |B|`.
```lean
example (α β : Type*) (f : α ↪ β) (g : β ↪ α) : ∃ e : α ≃ β, True :=
  ⟨Function.Embedding.antisymm f g, trivial⟩
```

### `Fintype.card_le_of_injective`
If there's an injection `A → B` with `B` finite, then `|A| ≤ |B|`.
```lean
example [Fintype α] [Fintype β] (f : α → β) (hf : Function.Injective f) :
    Fintype.card α ≤ Fintype.card β := Fintype.card_le_of_injective f hf
```

### `Fintype.card_le_of_surjective`
If there's a surjection `A → B`, then `|B| ≤ |A|`.
```lean
example [Fintype α] [Fintype β] (f : α → β) (hf : Function.Surjective f) :
    Fintype.card β ≤ Fintype.card α := Fintype.card_le_of_surjective f hf
```

### `Cardinal.mk_le_of_injective`
Injections give cardinal inequalities (infinite case).
```lean
-- Cardinal.mk_le_of_injective
```

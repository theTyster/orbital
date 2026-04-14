# Counting Principles

[Back to Index](../index.md)

Pigeonhole principle, inclusion-exclusion, and Fubini for finite sums/products.

---

### Pigeonhole Principle
**Pigeonhole Principle**: if `n` items are put into `m < n` boxes, some box has ≥ 2 items.
```lean
-- Finset.exists_lt_card_fiber_of_mul_lt_card or similar
example [DecidableEq β] (s : Finset α) (t : Finset β) (f : α → β)
    (hf : ∀ a ∈ s, f a ∈ t) (h : t.card * 1 < s.card) :
    ∃ b ∈ t, 1 < (s.filter (f · = b)).card := sorry
```

### `Finset.card_union_add_card_inter`
**Inclusion-exclusion** (two sets): `|A ∪ B| + |A ∩ B| = |A| + |B|`
```lean
example [DecidableEq α] (A B : Finset α) :
    (A ∪ B).card + (A ∩ B).card = A.card + B.card :=
  Finset.card_union_add_card_inter A B
```

### `Finset.sum_comm`
**Fubini for finite sums**: `∑_i ∑_j f(i,j) = ∑_j ∑_i f(i,j)`.
```lean
example [AddCommMonoid β] (s : Finset α) (t : Finset γ) (f : α → γ → β) :
    ∑ i in s, ∑ j in t, f i j = ∑ j in t, ∑ i in s, f i j := Finset.sum_comm
```

### `Finset.prod_comm`
**Fubini for finite products**: `∏_i ∏_j f(i,j) = ∏_j ∏_i f(i,j)`.
```lean
example [CommMonoid β] (s : Finset α) (t : Finset γ) (f : α → γ → β) :
    ∏ i in s, ∏ j in t, f i j = ∏ j in t, ∏ i in s, f i j := Finset.prod_comm
```

### `Finset.card_le_card`
Monotonicity of cardinality: if `A ⊆ B` then `|A| ≤ |B|`.
```lean
example [DecidableEq α] {A B : Finset α} (h : A ⊆ B) : A.card ≤ B.card :=
  Finset.card_le_card h
```

### `Fintype.card_fin`
`|Fin n| = n`.
```lean
example (n : Nat) : Fintype.card (Fin n) = n := Fintype.card_fin n
```

### `Finset.sum_bij`
**Bijective reindexing of sums**: if `f` bijects `s` onto `t`, sums transfer.
```lean
-- Finset.sum_bij for changing index sets
```

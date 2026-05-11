# Finite Sets

[Back to Index](../index.md)

Lemmas for `Finset` operations, cardinality, and summation.

---

### `Finset.mem_union`
Membership in a finite set union.
```lean
example (x : α) [DecidableEq α] (A B : Finset α) : x ∈ A ∪ B ↔ x ∈ A ∨ x ∈ B :=
  Finset.mem_union
```

### `Finset.mem_inter`
Membership in a finite set intersection.
```lean
example (x : α) [DecidableEq α] (A B : Finset α) : x ∈ A ∩ B ↔ x ∈ A ∧ x ∈ B :=
  Finset.mem_inter
```

### `Finset.card_union_add_card_inter`
Inclusion-exclusion: `|A ∪ B| + |A ∩ B| = |A| + |B|`
```lean
example [DecidableEq α] (A B : Finset α) :
    (A ∪ B).card + (A ∩ B).card = A.card + B.card :=
  Finset.card_union_add_card_inter A B
```

### `Finset.sum_empty`
Sum over the empty finset is zero.
```lean
example [AddCommMonoid β] (f : α → β) : ∑ x in (∅ : Finset α), f x = 0 := Finset.sum_empty
```

### `Finset.sum_singleton`
Sum over a singleton finset.
```lean
example [AddCommMonoid β] (a : α) (f : α → β) : ∑ x in {a}, f x = f a :=
  Finset.sum_singleton a f
```

### `Finset.sum_add_distrib`
Sum distributes over addition: `∑ x in s, (f x + g x) = ∑ x in s, f x + ∑ x in s, g x`
```lean
example [AddCommMonoid β] (s : Finset α) (f g : α → β) :
    ∑ x in s, (f x + g x) = ∑ x in s, f x + ∑ x in s, g x := Finset.sum_add_distrib
```

### `Finset.prod_empty`
Product over the empty finset is one.
```lean
example [CommMonoid β] (f : α → β) : ∏ x in (∅ : Finset α), f x = 1 := Finset.prod_empty
```

---

## See also

- [Sets](sets.md) -- `Set` operations (the non-finite counterpart)
- [Summation Formulas](../theorems/summation-formulas.md) -- closed-form summation identities
- [Cardinality](../theorems/cardinality.md) -- cardinality theorems for finite and infinite sets

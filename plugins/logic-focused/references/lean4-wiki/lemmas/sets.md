# Sets

[Back to Index](../index.md)

Lemmas for `Set` operations: union, intersection, complement, subset, and extensionality.

---

### `Set.mem_union`
Membership in a union: `x ∈ A ∪ B ↔ x ∈ A ∨ x ∈ B`
```lean
example (x : α) (A B : Set α) : x ∈ A ∪ B ↔ x ∈ A ∨ x ∈ B := Set.mem_union x A B
```

### `Set.mem_inter_iff`
Membership in an intersection: `x ∈ A ∩ B ↔ x ∈ A ∧ x ∈ B`
```lean
example (x : α) (A B : Set α) : x ∈ A ∩ B ↔ x ∈ A ∧ x ∈ B := Set.mem_inter_iff x A B
```

### `Set.subset_def`
Subset definition: `A ⊆ B ↔ ∀ x, x ∈ A → x ∈ B`
```lean
example (A B : Set α) : A ⊆ B ↔ ∀ x, x ∈ A → x ∈ B := Set.subset_def
```

### `Set.union_comm`
Union is commutative: `A ∪ B = B ∪ A`
```lean
example (A B : Set α) : A ∪ B = B ∪ A := Set.union_comm A B
```

### `Set.inter_comm`
Intersection is commutative: `A ∩ B = B ∩ A`
```lean
example (A B : Set α) : A ∩ B = B ∩ A := Set.inter_comm A B
```

### `Set.union_assoc`
Union is associative.
```lean
example (A B C : Set α) : A ∪ B ∪ C = A ∪ (B ∪ C) := Set.union_assoc A B C
```

### `Set.inter_assoc`
Intersection is associative.
```lean
example (A B C : Set α) : A ∩ B ∩ C = A ∩ (B ∩ C) := Set.inter_assoc A B C
```

### `Set.empty_union`
Union with the empty set: `∅ ∪ A = A`
```lean
example (A : Set α) : ∅ ∪ A = A := Set.empty_union A
```

### `Set.union_empty`
Union with the empty set on the right: `A ∪ ∅ = A`
```lean
example (A : Set α) : A ∪ ∅ = A := Set.union_empty A
```

### `Set.inter_univ`
Intersection with the universe: `A ∩ Set.univ = A`
```lean
example (A : Set α) : A ∩ Set.univ = A := Set.inter_univ A
```

### `Set.subset_union_left`
A set is a subset of its union with anything.
```lean
example (A B : Set α) : A ⊆ A ∪ B := Set.subset_union_left
```

### `Set.subset_union_right`
A set is a subset of its union on the right.
```lean
example (A B : Set α) : B ⊆ A ∪ B := Set.subset_union_right
```

### `Set.inter_subset_left`
An intersection is a subset of its left operand.
```lean
example (A B : Set α) : A ∩ B ⊆ A := Set.inter_subset_left
```

### `Set.ext`
Set extensionality: two sets are equal iff they have the same elements.
```lean
example (A B : Set α) (h : ∀ x, x ∈ A ↔ x ∈ B) : A = B := Set.ext h
```

### `Set.mem_compl_iff`
Membership in a complement: `x ∈ Aᶜ ↔ x ∉ A`
```lean
example (x : α) (A : Set α) : x ∈ Aᶜ ↔ x ∉ A := Set.mem_compl_iff A x
```

### `Set.image`
Image of a set under a function: `y ∈ f '' A ↔ ∃ x ∈ A, f x = y`
```lean
example (f : α → β) (A : Set α) (y : β) : y ∈ f '' A ↔ ∃ x ∈ A, f x = y := Set.mem_image f A y
```

### `Set.preimage`
Preimage of a set: `x ∈ f ⁻¹' B ↔ f x ∈ B`
```lean
example (f : α → β) (B : Set β) (x : α) : x ∈ f ⁻¹' B ↔ f x ∈ B := Iff.rfl
```

### `Set.iUnion`
Indexed union: `x ∈ ⋃ i, A i ↔ ∃ i, x ∈ A i`
```lean
example (A : ι → Set α) (x : α) : x ∈ ⋃ i, A i ↔ ∃ i, x ∈ A i := Set.mem_iUnion
```

### `Set.iInter`
Indexed intersection: `x ∈ ⋂ i, A i ↔ ∀ i, x ∈ A i`
```lean
example (A : ι → Set α) (x : α) : x ∈ ⋂ i, A i ↔ ∀ i, x ∈ A i := Set.mem_iInter
```

---

## See also

- [Finite Sets](finsets.md) -- `Finset` operations, cardinality, and summation
- [Lattice Operations](lattice-operations.md) -- `sup`, `inf`, and lattice structure (sets form a lattice)
- [Open & Closed Sets](open-closed-sets.md) -- topological set lemmas

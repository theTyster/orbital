# Open & Closed Sets

[Back to Index](../index.md)

Lemmas for open and closed sets in topological spaces.

---

### `isOpen_univ`
The universal set is open.
```lean
example [TopologicalSpace α] : IsOpen (Set.univ : Set α) := isOpen_univ
```

### `isOpen_empty`
The empty set is open.
```lean
example [TopologicalSpace α] : IsOpen (∅ : Set α) := isOpen_empty
```

### `IsOpen.union`
Union of two open sets is open.
```lean
example [TopologicalSpace α] {A B : Set α} (hA : IsOpen A) (hB : IsOpen B) : IsOpen (A ∪ B) :=
  hA.union hB
```

### `IsOpen.inter`
Intersection of two open sets is open.
```lean
example [TopologicalSpace α] {A B : Set α} (hA : IsOpen A) (hB : IsOpen B) : IsOpen (A ∩ B) :=
  hA.inter hB
```

### `isClosed_compl_iff`
A set is closed iff its complement is open.
```lean
example [TopologicalSpace α] (A : Set α) : IsClosed A ↔ IsOpen Aᶜ := isClosed_compl_iff
```

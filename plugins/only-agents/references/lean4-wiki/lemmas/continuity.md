# Continuity

[Back to Index](../index.md)

Lemmas for continuous functions between topological spaces.

---

### `Continuous.comp`
Composition of continuous functions is continuous.
```lean
example [TopologicalSpace α] [TopologicalSpace β] [TopologicalSpace γ]
    {f : β → γ} {g : α → β} (hf : Continuous f) (hg : Continuous g) :
    Continuous (f ∘ g) := hf.comp hg
```

### `continuous_id`
The identity function is continuous.
```lean
example [TopologicalSpace α] : Continuous (id : α → α) := continuous_id
```

### `continuous_const`
Constant functions are continuous.
```lean
example [TopologicalSpace α] [TopologicalSpace β] (b : β) : Continuous (fun _ : α => b) :=
  continuous_const
```

### `Continuous.prod_mk`
If `f` and `g` are continuous, so is `fun x => (f x, g x)`.
```lean
example [TopologicalSpace α] [TopologicalSpace β] [TopologicalSpace γ]
    {f : α → β} {g : α → γ} (hf : Continuous f) (hg : Continuous g) :
    Continuous (fun x => (f x, g x)) := hf.prod_mk hg
```

---

## See also

- [Open & Closed Sets](open-closed-sets.md) — topological primitives that continuity is defined in terms of
- [Compactness](../theorems/compactness.md) — extreme value theorem and Heine-Cantor for continuous functions on compact sets
- [Connectedness & Separation](../theorems/connectedness-separation.md) — intermediate value theorem and extension theorems

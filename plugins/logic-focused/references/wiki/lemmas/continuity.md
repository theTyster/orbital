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

# Functions

[Back to Index](../index.md)

Lemmas for function properties and composition.

---

### `Function.Injective`
A function is injective if `f a = f b → a = b`.
```lean
example : Function.Injective (fun n : Nat => n + 1) := fun _ _ h => Nat.succ.inj h
```

### `Function.Surjective`
A function is surjective if every element in the codomain has a preimage.
```lean
example : Function.Surjective (fun n : Int => n + 1) := fun b => ⟨b - 1, Int.sub_add_cancel b 1⟩
```

### `Function.comp_id`
Composing with the identity on the right: `f ∘ id = f`
```lean
example (f : α → β) : f ∘ id = f := Function.comp_id f
```

### `Function.id_comp`
Composing with the identity on the left: `id ∘ f = f`
```lean
example (f : α → β) : id ∘ f = f := Function.id_comp f
```

---

## See also

- [Cardinality](../theorems/cardinality.md) — injection/surjection bounds on cardinality, Cantor-Bernstein-Schroeder

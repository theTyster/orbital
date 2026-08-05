# Functors

[Back to Index](../index.md)

Lemmas for functor preservation of identity and composition.

---

### `CategoryTheory.Functor.map_id`
Functors preserve identity morphisms.
```lean
example [CategoryTheory.Category C] [CategoryTheory.Category D]
    (F : CategoryTheory.Functor C D) (X : C) :
    F.map (𝟙 X) = 𝟙 (F.obj X) := F.map_id X
```

### `CategoryTheory.Functor.map_comp`
Functors preserve composition.
```lean
example [CategoryTheory.Category C] [CategoryTheory.Category D]
    (F : CategoryTheory.Functor C D) {X Y Z : C} (f : X ⟶ Y) (g : Y ⟶ Z) :
    F.map (f ≫ g) = F.map f ≫ F.map g := F.map_comp f g
```

---

## See also

- [Categories](categories.md) — identity and associativity axioms for morphism composition
- [Famous Results](../theorems/famous-results.md) — Yoneda lemma (fully faithful embedding) and adjunctions

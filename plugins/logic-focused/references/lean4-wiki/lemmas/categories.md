# Categories

[Back to Index](../index.md)

Core category theory axioms: identity and associativity of morphism composition.

---

### `CategoryTheory.Category.id_comp`
Left identity for morphism composition: `𝟙 X ≫ f = f`
```lean
example [CategoryTheory.Category C] {X Y : C} (f : X ⟶ Y) :
    𝟙 X ≫ f = f := CategoryTheory.Category.id_comp f
```

### `CategoryTheory.Category.comp_id`
Right identity for morphism composition: `f ≫ 𝟙 Y = f`
```lean
example [CategoryTheory.Category C] {X Y : C} (f : X ⟶ Y) :
    f ≫ 𝟙 Y = f := CategoryTheory.Category.comp_id f
```

### `CategoryTheory.Category.assoc`
Associativity of morphism composition: `(f ≫ g) ≫ h = f ≫ (g ≫ h)`
```lean
example [CategoryTheory.Category C] {W X Y Z : C}
    (f : W ⟶ X) (g : X ⟶ Y) (h : Y ⟶ Z) :
    (f ≫ g) ≫ h = f ≫ (g ≫ h) := CategoryTheory.Category.assoc f g h
```

---

## See also

- [Functors](functors.md) — functor preservation of identity and composition
- [Famous Results](../theorems/famous-results.md) — Yoneda lemma and adjunction

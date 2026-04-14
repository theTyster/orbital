# Group Theory

[Back to Index](../index.md)

Lagrange's theorem, Sylow theorems, and the isomorphism theorems for groups.

---

### `Subgroup.card_subgroup_dvd_card`
**Lagrange's theorem**: the order of a subgroup divides the order of the group.
```lean
example [Group G] [Fintype G] (H : Subgroup G) [Fintype H] :
    Fintype.card H ∣ Fintype.card G := Subgroup.card_subgroup_dvd_card H
```

### `orderOf_dvd_card`
**Corollary of Lagrange**: the order of any element divides the group order.
```lean
example [Group G] [Fintype G] (g : G) : orderOf g ∣ Fintype.card G :=
  orderOf_dvd_card
```

### `Sylow.exists_subgroup_card_pow_prime`
**Sylow's first theorem**: if `p^k` divides `|G|`, then `G` has a subgroup of order `p^k`.
```lean
-- Sylow theorems are in Mathlib.GroupTheory.Sylow
example [Group G] [Fintype G] (p : Nat) [Fact (Nat.Prime p)] :
    ∃ H : Subgroup G, Fintype.card H = p ^ (Fintype.card G).factorization p := sorry
```

### `Sylow.card_sylow_modEq_one`
**Sylow's third theorem**: the number of Sylow p-subgroups is congruent to 1 mod p.
```lean
-- Formalized in Mathlib.GroupTheory.Sylow
```

### `QuotientGroup.quotientKerEquivRange`
**First Isomorphism Theorem** (for groups): `G / ker(f) ≅ im(f)`.
```lean
example [Group G] [Group H] (f : G →* H) :
    G ⧸ MonoidHom.ker f ≃* MonoidHom.range f :=
  QuotientGroup.quotientKerEquivRange f
```

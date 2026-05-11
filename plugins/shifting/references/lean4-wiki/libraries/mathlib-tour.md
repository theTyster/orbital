# Mathlib Tour

[Back to Index](../index.md)

A guided tour of Mathlib's top-level namespaces and what lives in each. Use this as a "where do I look?" reference: when a goal involves topology, the relevant lemmas are likely under `Mathlib.Topology`; when the goal is about a finite sum, search under `Finset` and `BigOperators`. Mathlib's structure mirrors mathematical taxonomy reasonably faithfully — knowing the taxonomy is half of finding the lemma.

---

## Top-level layout

```
Mathlib/
├── Init             — bootstrap, basic tactics, attribute setup
├── Logic            — propositional / first-order logic, classical foundations
├── Tactic           — tactic implementations (omega, linarith, polyrith, …)
├── Data             — concrete types and their basic theory (Nat, Int, List, Set, …)
├── Order            — order theory (Preorder, Lattice, GaloisConnection, …)
├── Algebra          — abstract algebra (Group, Ring, Module, …)
├── LinearAlgebra    — vector spaces, matrices, determinants, eigenvalues
├── Topology         — topological spaces, continuity, convergence
├── Analysis         — real/complex/functional analysis, calculus
├── MeasureTheory    — measures, integration, Lp spaces
├── Probability      — probability theory, random variables, expectations
├── Combinatorics    — finite combinatorics, graphs, partitions
├── NumberTheory     — primes, modular arithmetic, p-adic, Diophantine
├── Geometry         — Euclidean, manifolds (early-stage)
├── CategoryTheory   — categories, functors, limits, monoidal
├── RepresentationTheory — representations of groups
├── ModelTheory      — first-order model theory
├── SetTheory        — ordinals, cardinals, ZFC
└── …
```

This list is not exhaustive — Mathlib has hundreds of folders — but covers the namespaces you'll encounter most in everyday proofs.

---

## Namespace cheat sheet

### `Nat` — natural numbers
- `Nat.add_zero`, `Nat.zero_add`, `Nat.succ`, `Nat.pred`
- `Nat.lt_succ_iff`, `Nat.le_succ`, `Nat.lt_or_ge`
- `Nat.div`, `Nat.mod`, `Nat.gcd`, `Nat.lcm`
- `Nat.Prime`, `Nat.Coprime`
- `Nat.factorial`, `Nat.choose` (binomial coefficients)
- `Nat.rec`, `Nat.strong_induction_on`

### `Int` — integers
- `Int.add_neg`, `Int.sub_eq_add_neg`
- `Int.natAbs`, `Int.toNat`
- `Int.gcd`, `Int.dvd_iff_emod_eq_zero`
- Coercion: `Int → ℤ`, `Nat → ℤ`

### `Rat`, `Real`, `Complex` — number systems
- `Rat.num`, `Rat.den`, `Rat.cast`
- `Real.sqrt`, `Real.exp`, `Real.log`, `Real.sin`, `Real.cos`, `Real.pi`
- `Complex.I`, `Complex.abs`, `Complex.arg`, `Complex.exp`
- Conversion: `Real.toNNReal`, `NNReal`, `ENNReal`

### `List` — finite ordered sequences
- `List.length`, `List.append`, `List.map`, `List.filter`, `List.reverse`
- `List.head?`, `List.tail`, `List.headD`, `List.getLast?`
- `List.Pairwise`, `List.Sorted`, `List.Nodup`
- `List.foldl`, `List.foldr`
- `List.sum`, `List.prod` (in commutative monoids)

### `Array`, `Vector` — performance-oriented sequences
- `Array.size`, `Array.get`, `Array.set`, `Array.push`
- `Vector α n` for length-indexed arrays

### `Set` — abstract sets (subsets of a type)
- `Set.union`, `Set.inter`, `Set.compl`, `Set.diff`
- `Set.subset_def`, `Set.mem_setOf_eq`
- `Set.image`, `Set.preimage`
- `Set.Finite`, `Set.Countable`
- `Set.Nonempty`, `Set.Subsingleton`

### `Finset` — finite sets with decidable equality
- `Finset.card`, `Finset.union`, `Finset.inter`, `Finset.image`
- `Finset.sum`, `Finset.prod` (and `BigOperators` notation `∑ x ∈ s, …`)
- `Finset.range`, `Finset.Icc`, `Finset.Ico`
- `Finset.powerset`

### `Function` — generic function lemmas
- `Function.Injective`, `Function.Surjective`, `Function.Bijective`
- `Function.LeftInverse`, `Function.RightInverse`
- `Function.comp`, `Function.id`, `Function.const`
- `Function.update`

### `Equiv` — type equivalences (bijections with inverse)
- `Equiv.refl`, `Equiv.symm`, `Equiv.trans`
- `Equiv.toFun`, `Equiv.invFun`
- Specializations: `Equiv.Perm` (permutations), `Equiv.swap`

### `Order` & `Lattice`
- `Preorder`, `PartialOrder`, `LinearOrder`
- `OrderBot`, `OrderTop`, `BoundedOrder`
- `SemilatticeSup`, `SemilatticeInf`, `Lattice`, `CompleteLattice`
- `Monotone`, `StrictMono`, `Antitone`
- `IsLeast`, `IsGreatest`, `IsLUB`, `IsGLB`

### `Algebra` family
- `Semigroup`, `Monoid`, `Group`, `CommGroup`
- `AddSemigroup`, `AddMonoid`, `AddGroup`, `AddCommGroup`
- `Semiring`, `Ring`, `CommRing`, `Field`
- `Module`, `Algebra` (over a base ring)
- Quotients: `QuotientGroup`, `QuotientRing`

### `LinearAlgebra`
- `LinearMap`, `LinearEquiv`
- `Submodule`, `Subspace`
- `Matrix`, `Matrix.det`, `Matrix.trace`
- `Basis`, `FiniteDimensional`
- `Eigenvalue`, `Eigenvector`

### `Polynomial`
- `Polynomial R` for univariate polynomials over a ring `R`
- `Polynomial.eval`, `Polynomial.degree`, `Polynomial.coeff`
- `Polynomial.roots`, `Polynomial.IsRoot`
- `MvPolynomial` for multivariate

### `Topology`
- `TopologicalSpace`
- `IsOpen`, `IsClosed`, `Closure`, `Interior`, `Frontier`
- `Continuous`, `ContinuousAt`, `ContinuousOn`
- `Filter`, `Tendsto`, `Filter.atTop`, `Filter.nhds`
- `Compact`, `Connected`, `Hausdorff` (`T2Space`)
- `MetricSpace`, `NormedSpace`, `Banach`, `Hilbert`

### `Analysis`
- `Differentiable`, `HasDerivAt`, `deriv`
- `MeanValueTheorem`
- `intervalIntegral`, `MeasureTheory.integral`
- `Asymptotics.IsBigO`, `Asymptotics.IsLittleO`
- `Convex`

### `MeasureTheory`
- `MeasurableSpace`, `Measurable`, `MeasurableSet`
- `Measure`, `OuterMeasure`
- `MeasureTheory.integral`, `MeasureTheory.Lp`
- `MeasureTheory.AEMeasurable`, `ae_iff`

### `Probability`
- `ProbabilityMeasure`, `IsProbabilityMeasure`
- `IndepFun`, `IndepEvents`
- `condExp` (conditional expectation)
- `MeasureTheory.lintegral`

### `Combinatorics`
- `SimpleGraph`, `Walk`, `Path`, `Trail`, `Connected`
- `Equiv.Perm.cycleType`, `Equiv.Perm.sign`
- `Nat.choose`, `Nat.descFactorial`
- `Pigeonhole`, `Hall's marriage theorem`

### `NumberTheory`
- `Nat.Prime`, `Nat.totient`, `Nat.minFac`
- `ZMod n` (integers mod n)
- `Padic`, `PadicInt`
- `LegendreSym`, `JacobiSym`
- `Finite`, `Cardinal`, `Cardinal.aleph0`

### `CategoryTheory`
- `Category`, `Functor`, `NatTrans`, `Equivalence`
- `Limits`, `Colimits`, `Pullback`, `Pushout`
- `Adjunction`, `IsLeftAdjoint`, `IsRightAdjoint`
- `MonoidalCategory`

### `Tactic` (tactic implementations)
- `Tactic.Linarith`, `Tactic.Polyrith`, `Tactic.Positivity`
- `Tactic.NormNum`, `Tactic.Ring`, `Tactic.FieldSimp`
- `Tactic.Omega`, `Tactic.Decide`
- `Tactic.LibrarySearch` (now `exact?`)
- `Aesop`

---

## Notation namespaces

Mathlib defines notation in opt-in scopes. Common ones:
- `BigOperators` — `∑ x ∈ s, f x`, `∏ x ∈ s, f x`
- `Classical` — classical logic axioms (`Classical.em`, `Classical.choose`)
- `NNReal`, `ENNReal` — non-negative and extended-non-negative reals
- `Topology`, `Filter` — neighborhood and filter notations
- `Pointwise` — pointwise operations on sets (`s + t`, `s * t`)
- `Matrix` — matrix notation
- `Polynomial` — polynomial notation, `X`, `C`

Open with `open scoped <Name>` (e.g. `open scoped BigOperators`).

---

## Common search targets

| You want | Search under |
| --- | --- |
| Lemmas about `n + 0 = n` for `n : ℕ` | `Nat.add_zero`, or in general `add_zero` |
| Lemmas about `xs.length` for lists | `List.length`, `List.length_append`, `List.length_map` |
| Lemmas about set union | `Set.union`, `Set.mem_union`, `Set.union_comm` |
| Continuity of a composition | `Continuous.comp`, `ContinuousAt.comp` |
| Properties of primes | `Nat.Prime`, `Nat.Prime.eq_one_or_self_of_dvd` |
| Finite sums | `Finset.sum`, `Finset.sum_add_distrib`, `Finset.sum_range_succ` |
| Differentiation rules | `deriv_add`, `deriv_mul`, `HasDerivAt.add` |
| Group homomorphism preserves identity | `MonoidHom.map_one`, `MonoidHom.map_mul` |
| Measure of a finite set | `MeasureTheory.measure_finite_eq_card` (or similar) |
| Closure of a topological set | `closure_eq_iff`, `IsClosed.closure_eq` |

---

## Finding lemmas you can't name

Mathlib is huge. When you don't know the name:

1. **`exact?`** — given the current goal, search for a closing lemma. See [Library Search and Tactic Suggestion](../tactics/library-search-and-suggestion.md).
2. **`loogle`** (https://loogle.lean-lang.org) — pattern search by lemma shape, not by goal. Accepts holes (`?_`).
3. **`#find`** — Mathlib command for in-file pattern search. Same idea as `loogle` but runs locally.
4. **Naming conventions** — see [Mathlib Naming Conventions](../idioms/naming-conventions.md). Often you can guess the name.
5. **Github search** — when all else fails, search the Mathlib repo on GitHub for the operation or relation you need.

---

## Mathlib version note

Mathlib evolves continuously — file paths, lemma names, and namespace organization shift between versions. This tour describes Mathlib as of mid-2026; for older or newer code, the high-level structure is stable but specific paths may differ.

When upgrading:
- Run `lake update` to fetch the new Mathlib.
- Re-build; the compiler will report renamed lemmas with their new names.
- For broad renames, the [Mathlib changelog](https://github.com/leanprover-community/mathlib4/blob/master/changelog.md) is the canonical reference (when maintained).

---

## See also

- [Mathlib Naming Conventions](../idioms/naming-conventions.md) — the rules for guessing lemma names
- [Library Search and Tactic Suggestion](../tactics/library-search-and-suggestion.md) — `exact?`, `loogle`, `#find`
- All [Lemmas](../index.md#lemmas) and [Theorems](../index.md#theorems) entries — concrete coverage of the namespaces above

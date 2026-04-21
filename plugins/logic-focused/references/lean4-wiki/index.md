# Lean 4 Wiki

A general knowledge source for Lean 4 and Mathlib: lemmas, theorems, tactics, idioms, and anything else worth cataloguing. Every entry lives inside a category subdirectory so the index stays navigable as the wiki grows. Today there are two categories (`lemmas/` and `theorems/`); new categories (e.g. `tactics/`, `idioms/`, `libraries/`) can be added alongside them following the same pattern.

## Structure

```
lean4-wiki/
├── index.md         — this file (wiki entry point + topic map)
├── lemmas/          — Mathlib lemmas organized by mathematical domain
├── theorems/        — famous Mathlib theorems with worked Lean 4 examples
└── <future-category>/ — additional topic areas as needed
```

Every category directory should contain one markdown file per entry, named after the topic in kebab-case.

## Lemmas

Core lemmas organized by type and algebraic structure.

### Arithmetic & Numbers
- [Natural Number Arithmetic](lemmas/nat-arithmetic.md) — add, mul, succ, sub, commutativity, associativity, identities
- [Natural Number Ordering](lemmas/nat-ordering.md) — le, lt, reflexivity, transitivity, irreflexivity
- [Natural Number Divisibility](lemmas/nat-divisibility.md) — dvd, mod, div, gcd
- [Integer Arithmetic](lemmas/int-arithmetic.md) — add, mul, neg, abs for integers

### Abstract Algebra
- [Additive Structures](lemmas/additive-structures.md) — AddCommMonoid, AddSemigroup, AddGroup lemmas
- [Multiplicative Structures](lemmas/multiplicative-structures.md) — Monoid, CommMonoid, Group, Field lemmas
- [Ring & Field Operations](lemmas/ring-field-operations.md) — distributivity, division, inverses
- [Powers & Exponents](lemmas/powers-exponents.md) — pow_zero, pow_one, pow_succ, pow_add, pow_mul

### Order & Lattice
- [Order Relations](lemmas/order-relations.md) — le, lt, min, max for Preorder and LinearOrder
- [Lattice Operations](lemmas/lattice-operations.md) — sup, inf, sup_le, le_inf

### Logic & Propositions
- [Connectives](lemmas/connectives.md) — And, Or, Iff introduction and elimination
- [Equality](lemmas/equality.md) — Eq.symm, Eq.trans, congrArg, funext, propext
- [Quantifiers & Classical](lemmas/quantifiers-classical.md) — Exists, not_not, Classical.em, byContradiction, absurd

### Data Structures
- [Sets](lemmas/sets.md) — union, intersection, complement, subset, extensionality
- [Finite Sets](lemmas/finsets.md) — Finset union, intersection, cardinality, sums
- [Lists](lemmas/lists.md) — append, length, map, reverse, membership, filter
- [Functions](lemmas/functions.md) — injective, surjective, comp_id, id_comp

### Analysis
- [Absolute Value & Norms](lemmas/absolute-value-norms.md) — abs_nonneg, abs_add, abs_mul, abs_sub_comm
- [Real Functions](lemmas/real-functions.md) — sqrt, exp, log identities

### Topology
- [Open & Closed Sets](lemmas/open-closed-sets.md) — isOpen_univ, IsOpen.union, IsOpen.inter, isClosed_compl_iff
- [Continuity](lemmas/continuity.md) — Continuous.comp, continuous_id, continuous_const

### Linear Algebra
- [Submodules](lemmas/submodules.md) — add_mem, zero_mem, smul_mem
- [Linear Maps](lemmas/linear-maps.md) — map_add, map_smul, map_zero

### Category Theory
- [Categories](lemmas/categories.md) — id_comp, comp_id, assoc
- [Functors](lemmas/functors.md) — map_id, map_comp

### Misc
- [Tactic-Adjacent](lemmas/tactic-adjacent.md) — inequalities, division, if-simplification
- [Misc Types](lemmas/misc-types.md) — Prod, Option, Fin, Equiv, cast

---

## Theorems

Famous mathematical theorems formalized in Mathlib.

### Number Theory
- [Primes & Divisibility](theorems/primes-divisibility.md) — Euclid's theorem, Euclid's lemma, FTA, factor theorem
- [Modular Arithmetic](theorems/modular-arithmetic.md) — CRT, Fermat's little theorem, Euler's theorem, Wilson's theorem
- [Summation Formulas](theorems/summation-formulas.md) — Gauss summation, geometric series

### Algebra
- [Group Theory](theorems/group-theory.md) — Lagrange, Sylow theorems, isomorphism theorems
- [Ring & Polynomial Theory](theorems/ring-polynomial-theory.md) — Hilbert's basis theorem, division algorithm, FTA (algebra), Cayley-Hamilton
- [Commutative Algebra](theorems/commutative-algebra.md) — maximal/prime ideals, Nakayama, localization
- [Field & Galois Theory](theorems/field-galois-theory.md) — tower law, fundamental theorem of Galois theory, algebraic closure

### Analysis
- [Series & Convergence](theorems/series-convergence.md) — geometric series, Basel problem
- [Integration](theorems/integration.md) — linearity, FTC, monotone/dominated convergence, substitution
- [Inequalities](theorems/inequalities.md) — Cauchy-Schwarz, triangle inequality, AM-GM, Holder, Minkowski

### Differential Calculus
- [Differentiation Rules](theorems/differentiation-rules.md) — sum, product, chain, quotient, power rules
- [Standard Derivatives](theorems/standard-derivatives.md) — exp, log, sin, cos
- [Mean Value Theorems](theorems/mean-value-theorems.md) — Rolle, MVT, Fermat's stationary points, Taylor

### Topology
- [Compactness](theorems/compactness.md) — Heine-Borel, extreme value theorem, Heine-Cantor, Tychonoff
- [Connectedness & Separation](theorems/connectedness-separation.md) — IVT, Urysohn, Tietze extension
- [Completeness & Fixed Points](theorems/completeness-fixed-points.md) — Banach fixed point, Baire category

### Linear Algebra & Matrices
- [Fundamental Theorems](theorems/linear-algebra-fundamentals.md) — rank-nullity, bases, Riesz representation, spectral theorem
- [Determinants & Trace](theorems/determinants-trace.md) — det multiplicativity, det transpose, trace cyclicity

### Combinatorics
- [Binomial Coefficients](theorems/binomial-coefficients.md) — binomial theorem, Pascal's rule, Vandermonde
- [Counting Principles](theorems/counting-principles.md) — pigeonhole, inclusion-exclusion, Fubini for sums

### Set Theory & Logic
- [Cardinality](theorems/cardinality.md) — Cantor's theorem, Cantor-Bernstein-Schroeder, injection/surjection bounds
- [Foundations](theorems/foundations.md) — Zorn's lemma, axiom of choice, well-ordering, transfinite induction

### Measure Theory & Probability
- [Measure Foundations](theorems/measure-foundations.md) — countable additivity/subadditivity, measure extensionality
- [Probability](theorems/probability.md) — strong law of large numbers, CLT, variance bounds

### Functional Analysis
- [Hilbert & Banach Spaces](theorems/hilbert-banach-spaces.md) — orthogonal projection, Riesz representation, operator norms

### Geometry
- [Inner Product Geometry](theorems/inner-product-geometry.md) — Pythagorean theorem, parallelogram law, Cauchy-Schwarz

### Miscellaneous
- [Famous Results](theorems/famous-results.md) — irrationality of √2, Euler's formula, Stirling, symmetric polynomials, permutation signs

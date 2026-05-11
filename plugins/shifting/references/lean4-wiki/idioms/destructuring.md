# Destructuring

[Back to Index](../index.md)

Tactics and term-level patterns for breaking apart structured data. The hypothesis `h : ∃ x, P x ∧ Q x` is far more useful when you split it into `x`, `hp : P x`, `hq : Q x`. Lean has a small family of tactics for this — `obtain`, `rcases`, `rintro` — plus the term-mode anonymous constructor `⟨_, _⟩`. Knowing which to reach for is the difference between four lines of `cases` ceremony and one line of `obtain`.

---

## Quick reference

| You have | You want | Tactic |
| --- | --- | --- |
| `h : A ∧ B` | `ha : A`, `hb : B` | `obtain ⟨ha, hb⟩ := h` |
| `h : A ∨ B` | two branches with `ha : A` and `hb : B` | `rcases h with ha \| hb` |
| `h : ∃ x, P x` | `x : α`, `hp : P x` | `obtain ⟨x, hp⟩ := h` |
| `h : ∃ x, A x ∧ B x` | `x`, `ha : A x`, `hb : B x` | `obtain ⟨x, ha, hb⟩ := h` |
| Goal `A ∧ B` from terms | provide `⟨proofA, proofB⟩` | term mode `⟨…, …⟩` |
| Goal `∃ x, P x` | provide `⟨witness, proof⟩` | term mode `⟨w, hp⟩` |
| Hypothesis `A → B → C` to apply | `intro` then destructure | `rintro ha hb` |
| Inductive case split | one branch per constructor | `rcases h with ⟨…⟩ \| ⟨…⟩ \| ⟨…⟩` |
| Need to *introduce* a hypothesis and destructure in one step | combine `intro` and `rcases` | `rintro ⟨…⟩` |

---

### `obtain`
The standard destructuring tactic. Patterns are written with anonymous-constructor notation `⟨…⟩` and disjunction notation `… | …`.
```lean
example (h : ∃ n : ℕ, n > 5 ∧ n < 10) : True := by
  obtain ⟨n, hgt, hlt⟩ := h
  trivial

example (h : (∃ n, n > 5) ∨ False) : True := by
  obtain ⟨n, hn⟩ | hfalse := h
  · trivial
  · exact False.elim hfalse
```
**Idiom:** `obtain` is `rcases` with nicer syntax for the common case of a single pattern. They are interchangeable; teams typically pick one and stay consistent. Mathlib trends toward `obtain`.

### `rcases`
Recursive case analysis. Identical capability to `obtain`, with a slightly different surface syntax (`rcases h with pattern`).
```lean
example (h : (∃ n : ℕ, n > 5) ∨ True) : True := by
  rcases h with ⟨n, hn⟩ | htrue
  · trivial
  · exact htrue
```
Patterns:
- `⟨a, b⟩` — destructure a conjunction or sigma type
- `⟨a, b, c⟩` — nested destructuring (right-associative)
- `a | b` — disjunction (one branch each)
- `_` — discard / anonymous binder
- `-` — clear the hypothesis after destructuring (don't bind a name)
- `rfl` — substitute the equality immediately

```lean
example (h : ∃ n m : ℕ, n + m = 0) : True := by
  rcases h with ⟨n, m, _⟩
  trivial

example (a b : ℕ) (h : a = b) (h' : a + 1 = 5) : b + 1 = 5 := by
  rcases h with rfl   -- substitutes a := b throughout
  exact h'
```

### `rintro`
The combination of `intro` and `rcases`. Where `intro` introduces a hypothesis and `rcases` destructures it, `rintro` does both with the destructuring pattern as the binder.
```lean
-- without rintro
example : (∃ n : ℕ, n > 5) → True := by
  intro h
  obtain ⟨n, hn⟩ := h
  trivial

-- with rintro
example : (∃ n : ℕ, n > 5) → True := by
  rintro ⟨n, hn⟩
  trivial
```
**Idiom:** `rintro` shines on iterated implications:
```lean
example : (∃ n : ℕ, n > 5) → (∃ m : ℕ, m < 3) → True := by
  rintro ⟨n, hn⟩ ⟨m, hm⟩
  trivial
```

### Term-mode anonymous constructor `⟨…⟩`
Mirror image of `obtain`: provides a term of a structure type by listing the constructor's arguments without naming the constructor.
```lean
example : ∃ n : ℕ, n > 5 := ⟨6, by norm_num⟩
example (a b : ℕ) (ha : 0 < a) (hb : 0 < b) : 0 < a ∧ 0 < b := ⟨ha, hb⟩
example : Σ n : ℕ, n > 5 := ⟨6, by norm_num⟩
```
Nested:
```lean
example : ∃ n m : ℕ, n + m = 5 := ⟨2, 3, rfl⟩
example : (∃ n : ℕ, n > 0) ∧ (∃ m : ℕ, m < 10) := ⟨⟨1, by norm_num⟩, ⟨5, by norm_num⟩⟩
```
**Idiom:** `⟨…⟩` works for any structure with a single constructor (`And`, `Exists`, `Sigma`, user-defined `structure`s). For multi-constructor types like `Or`, use `Or.inl` / `Or.inr` or the named version.

### `cases` (more primitive)
The fundamental case analysis tactic. Splits a hypothesis by its constructors, producing one goal per constructor.
```lean
example (h : ℕ) : True := by
  cases h with
  | zero => trivial
  | succ n => trivial
```
**Distinguishing feature:** `cases` is more verbose and less pattern-friendly than `rcases`. It does respect Lean's strict structural totality, which makes it the right tool when you specifically want named constructor branches and exhaustiveness checking.

`cases` syntax variants:
```lean
-- with named cases
example (h : ℕ ⊕ Bool) : True := by
  cases h with
  | inl n => trivial
  | inr b => trivial

-- inline
example (h : ℕ) : True := by
  cases h
  case zero => trivial
  case succ n => trivial
```

---

## Common patterns

**Pattern 1 — `obtain` for chained existentials and conjunctions.**
```lean
example (h : ∃ n m : ℕ, n + m = 0 ∧ n * m = 0) : True := by
  obtain ⟨n, m, hadd, hmul⟩ := h
  trivial
```
The anonymous-constructor pattern is right-associative, so `⟨n, m, hadd, hmul⟩` unwraps `∃ n, ∃ m, _ ∧ _` in one shot.

**Pattern 2 — `rcases` for disjunctive hypotheses.**
```lean
example (n : ℕ) (h : n = 0 ∨ 0 < n) : 0 ≤ n := by
  rcases h with rfl | hpos
  · exact le_refl 0
  · exact le_of_lt hpos
```
`rfl` in a pattern position immediately substitutes the equality, eliminating one variable.

**Pattern 3 — `rintro` to skip a manual `intro` step.**
```lean
example : ∀ n : ℕ, (∃ m, n = 2 * m) → Even n := by
  rintro n ⟨m, rfl⟩
  exact ⟨m, by ring⟩
```
The `rfl` pattern inside `rintro` substitutes the equality back into the goal.

**Pattern 4 — discard with `_` and `-`.**
```lean
example (h : ∃ n m : ℕ, n + m = 5) : True := by
  obtain ⟨_, _, _⟩ := h
  trivial
```
Use `-` instead of `_` if you want the hypothesis cleared from context entirely (rather than bound to an inaccessible name).

**Pattern 5 — `⟨…⟩` for proof-by-witness.**
```lean
example (n : ℕ) (h : n = 5) : ∃ m, m + 1 = 6 := ⟨n, by omega⟩
```
Provide the witness and the proof in one term — often shorter than `use n; omega`.

**Pattern 6 — destructure a `Subtype` (`{x // P x}`) value.**
```lean
example (s : {n : ℕ // n > 5}) : s.val > 5 := by
  obtain ⟨n, hn⟩ := s
  exact hn
```
`Subtype` is just `Sigma` in disguise; the same `⟨val, prop⟩` pattern works.

**Pattern 7 — destructure inside a `have`.**
```lean
example (h : ∃ n : ℕ, n > 5 ∧ n < 10) : True := by
  have ⟨n, hgt, hlt⟩ := h
  trivial
```
`have` with a destructuring pattern is a sometimes-cleaner alternative to `obtain`, especially in term-mode contexts.

---

## Limits and pitfalls

- **`rcases`/`obtain` patterns are right-associative.** `⟨a, b, c⟩` parses as `⟨a, ⟨b, c⟩⟩`. For a flat n-ary tuple, this matches; for nested structures with three single-constructor types, you may need to be explicit: `⟨a, ⟨b, c⟩⟩` versus `⟨⟨a, b⟩, c⟩`.
- **`rintro` does not implicitly clear.** Variables you introduce stay in the context until the end of the proof. For long proofs, consider `clear` after destructuring.
- **`cases h with rfl`-style substitution requires `h` to be an equality with one side a free variable.** `cases h` on `h : a = b + 1` will not substitute; you need `subst h` (or `rcases h with rfl`, which is friendlier).
- **`⟨…⟩` term mode infers the structure from the expected type.** If the expected type is ambiguous (e.g. assigned to `_`), Lean cannot pick a constructor and you'll see "anonymous constructor used in non-anonymous-friendly position" errors. Add a type ascription: `(⟨a, b⟩ : MyStructure)`.
- **`rcases` with `Or` requires named patterns on each side.** `rcases h with ha | hb` works; bare `rcases h with _ | _` works for discard, but mixing destructuring patterns on both sides is fine (`rcases h with ⟨a, b⟩ | hc`).

---

## See also

- [Structuring Proofs](structuring-proofs.md) — `have`, `suffices`, `refine` — the structural skeletons that destructuring fills
- [Connectives](../lemmas/connectives.md) — `And`, `Or`, `Iff` constructors and eliminators
- [Quantifiers & Classical](../lemmas/quantifiers-classical.md) — `Exists`, `Classical.choose`, the term-level analogues to existential destructuring
- [Misc Types](../lemmas/misc-types.md) — `Prod`, `Option`, `Sum`, `Sigma` — the destructurable types beyond `And`/`Or`/`Exists`

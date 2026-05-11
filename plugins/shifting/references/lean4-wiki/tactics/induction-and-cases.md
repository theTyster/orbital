# Induction and Cases

[Back to Index](../index.md)

Tactics that recurse on inductive structure. `induction` peels apart a value by its constructors and gives you an induction hypothesis for each recursive position; `cases` does the same without the IH; `rcases`/`obtain` handle the destructuring side. Knowing which to reach for, and which induction principle to invoke, is half the battle on any recursive proof.

---

## Quick decision table

| Situation | Tactic | Notes |
| --- | --- | --- |
| Recursing on `n : ℕ` (predecessor pattern) | `induction n` | classic `zero` / `succ` split |
| Recursing on `n : ℕ` and need access to all smaller values | `Nat.strong_induction_on` | strong induction |
| Splitting `xs : List α` head-from-tail | `induction xs` | `nil` / `cons` split |
| Generalizing the induction over a hypothesis | `induction n with` (after `induction n generalizing x`) | keeps the hypothesis polymorphic |
| Just the case split, no IH needed | `cases n` | simpler than `induction` |
| Pattern-rich case analysis on a structured term | `rcases h with …` | see [Destructuring](../idioms/destructuring.md) |
| Custom induction principle for a user-defined recursive type | `induction h using <principle>` | e.g. `induction h using Acc.rec` |
| Well-founded recursion (Acc, Quot, etc.) | `WellFoundedRecursion`, `induction h using …` | rare; usually `Nat.strong_induction_on` is enough |
| Two-step induction (`fib`-style) | `Nat.strong_induction_on` or a custom recursor | classic IH on `n` and `n - 1` |
| Inductive on the structure of an inductive proposition | `induction h` | induction on `Even n`, `Acc r a`, etc. |

---

### `induction`
The fundamental induction tactic. Splits the target into one goal per constructor of the inductive type, with an induction hypothesis (IH) provided for each recursive argument.
```lean
example (n : ℕ) : 0 + n = n := by
  induction n with
  | zero => rfl
  | succ k ih => rw [Nat.add_succ, ih]
```
Each `case` names the constructor; `ih` is the induction hypothesis for the recursive argument. Inside the `succ` case, `ih : 0 + k = k`.

**Idiom:** the `induction n with | … | …` syntax is preferred over older `induction n; · …; · …` because it makes case names explicit.

### `induction … generalizing`
By default, `induction n` keeps every hypothesis depending on `n` *fixed* — but the IH is only useful if it generalizes over those hypotheses. Use `generalizing` to revert + induct + reintroduce:
```lean
example (m n : ℕ) : n + m = m + n := by
  induction n generalizing m with
  | zero => simp
  | succ k ih => rw [Nat.succ_add, ← ih, Nat.add_succ]
```
**When to use:** if your IH would not apply because some hypothesis is "stuck" at a specific `n`, generalize it first. A common case: induction over a list while a `Sorted` predicate must adapt to each tail.

### `cases`
Splits a value into one goal per constructor without producing an IH. Use when you don't need recursion — just the case split.
```lean
example (n : ℕ) : 0 ≤ n := by
  cases n with
  | zero => rfl
  | succ k => exact Nat.zero_le _
```
**Cases versus induction:** if you reach for the IH inside a branch, you needed `induction`. If you don't, `cases` is simpler and produces less noise.

### `Nat.strong_induction_on` and strong induction
The "all smaller values, not just predecessor" recursor. Use when the IH must apply to *some* smaller value, not just `n - 1`.
```lean
example (n : ℕ) (P : ℕ → Prop) (h : ∀ k, (∀ m, m < k → P m) → P k) : P n := by
  induction n using Nat.strong_induction_on with
  | _ k ih => exact h k ih
```
**Idiom:** any time `n - 1` is not the right step (e.g. dividing by 2, splitting a list in halves), strong induction is the right tool. Mathlib also has `Nat.le_induction`, `Nat.rec_two_step`, etc. — `induction n using <name>` is the form for invoking them.

### Induction on inductive propositions
`induction h` works on hypotheses whose type is an inductive proposition. The cases are the constructors of the proposition.
```lean
example (n : ℕ) (h : Even n) : ∃ k, n = 2 * k := by
  induction h with
  | even_iff_exists_two_mul => sorry  -- (constructor names depend on Mathlib's Even definition)
```
Actual Mathlib `Even`: `def Even (n : α) := ∃ r, n = r + r`. So this would more cleanly be `obtain ⟨k, hk⟩ := h; …`. The `induction h` form is most common on:
- `Acc r a` (well-founded relations)
- `List.Forall p xs`, `List.Sorted r xs`
- Custom inductive predicates you've defined

```lean
inductive MyEven : ℕ → Prop where
  | zero : MyEven 0
  | step : ∀ n, MyEven n → MyEven (n + 2)

example (n : ℕ) (h : MyEven n) : ∃ k, n = 2 * k := by
  induction h with
  | zero => exact ⟨0, by ring⟩
  | step n hn ih =>
    obtain ⟨k, hk⟩ := ih
    exact ⟨k + 1, by omega⟩
```

### `induction'` (Mathlib variant)
Mathlib's `induction'` is a more flexible form that handles `with` patterns more like `rcases`. Less commonly needed in modern Lean 4, but still appears in older proofs.

### Subgoal generalization with `revert`/`intro`
Sometimes you need to set up the goal before inducting:
```lean
example (m n : ℕ) (h : m ≤ n) : m + 0 ≤ n + 0 := by
  revert h
  induction n with
  | zero => intro h; omega
  | succ k ih => intro h; omega
```
This is the manual version of `induction n generalizing m`. `generalizing` is preferred when it suffices.

### Mutual induction
For mutually recursive types, induction proceeds with one goal per constructor across all types. Lean handles this automatically when you `induction` on a value of a mutually defined inductive.

---

## Common patterns

**Pattern 1 — induction on `ℕ` with `succ` IH.**
```lean
example (n : ℕ) : List.range n = (List.range n).map id := by
  induction n with
  | zero => rfl
  | succ k ih => rw [List.range_succ, List.map_append, ih]; rfl
```

**Pattern 2 — `generalizing` to keep the IH usable.**
```lean
example (xs : List ℕ) (n : ℕ) : xs.length + n = n + xs.length := by
  induction xs generalizing n with
  | nil => simp
  | cons x xs ih =>
    simp [List.length_cons]
    omega
```
Without `generalizing n`, the IH would be stuck at the original `n` and the recursive call wouldn't apply.

**Pattern 3 — strong induction for half-the-list / divide-and-conquer.**
```lean
example (n : ℕ) (P : ℕ → Prop) (h0 : P 0)
    (hstep : ∀ k, (∀ m, m < k → P m) → P k) : P n := by
  induction n using Nat.strong_induction_on with
  | _ k ih => exact hstep k ih
```

**Pattern 4 — `cases` when the IH is unused.**
```lean
example (n : ℕ) : n = 0 ∨ ∃ k, n = k + 1 := by
  cases n with
  | zero => exact Or.inl rfl
  | succ k => exact Or.inr ⟨k, rfl⟩
```
No recursive call needed — `cases` is shorter and clearer than `induction`.

**Pattern 5 — induction on a list, with the standard nil/cons split.**
```lean
example (xs : List α) (f : α → α) : (xs.map f).length = xs.length := by
  induction xs with
  | nil => rfl
  | cons x xs ih => simp [List.map, List.length_cons, ih]
```

**Pattern 6 — induction on an inductive proposition for structural reasoning.**
```lean
inductive Sorted : List ℕ → Prop where
  | nil : Sorted []
  | singleton : ∀ x, Sorted [x]
  | cons : ∀ x y xs, x ≤ y → Sorted (y :: xs) → Sorted (x :: y :: xs)

example (xs : List ℕ) (h : Sorted xs) : xs.Pairwise (· ≤ ·) := by
  induction h with
  | nil => exact List.Pairwise.nil
  | singleton x => exact List.pairwise_singleton _ _ |>.mpr trivial
  | cons x y xs hxy hsort ih => sorry
```
Each constructor of `Sorted` gives one branch; the recursive `cons` case provides an IH on the tail.

---

## Limits and pitfalls

- **Forgetting `generalizing`.** The most common induction failure: the IH is too specific to apply at the recursive call. Symptom: you have an IH about `k`, but you need it about `k + 1` or some derived value. Fix: `induction n generalizing <hypotheses>`.
- **`induction` on a non-inductive type.** `induction n` on `n : ℝ` will fail — `ℝ` is not inductive. Use `cases` on `Real.lt_iff_lt_of_le_iff_le` or restructure.
- **Strong induction with a dependent hypothesis.** `Nat.strong_induction_on` expects `P : ℕ → Prop`. If your goal depends on more than `n`, generalize first or use `revert` to assemble the right `P`.
- **Case names shifting between Lean versions.** Constructor names occasionally rename in Mathlib. Pin proofs with the `case` syntax (e.g. `case zero =>`) so the locality is explicit; bare positional matches are fragile.
- **Custom recursors and `induction … using`.** When invoking a custom recursor, the goals may not align with the recursor's named arguments. If `with | … | …` confuses Lean, fall back to bullet-style and use `case <name> =>` to pin each branch.

---

## See also

- [Destructuring](../idioms/destructuring.md) — `rcases`, `obtain`, `rintro` for breaking apart structures (common partner with `cases`)
- [Structuring Proofs](../idioms/structuring-proofs.md) — bullets and `case` focus, used heavily inside induction proofs
- [Library Search and Tactic Suggestion](library-search-and-suggestion.md) — `exact?` after each induction case is a high-leverage move
- [Foundations](../theorems/foundations.md) — Zorn's lemma, transfinite induction, well-orderings — the heavy machinery beyond `Nat`

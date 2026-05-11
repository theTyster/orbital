# Simp and Rewriting

[Back to Index](../index.md)

The rewriting tactics are how Lean proofs reshape goals. `simp` is the workhorse simplifier; `rw` is the precision tool; `conv` lets you focus on a subterm; `dsimp` does definitional simplification only. The choice between them is the difference between a brittle proof and a robust one.

---

## Quick decision table

| You want to... | Tactic | Notes |
| --- | --- | --- |
| Apply *one specific* equality at the goal | `rw [h]` | precise, leaves nothing to chance |
| Apply many lemmas, simplify whatever fits | `simp` | fragile in production — pin with `only` |
| Pin a `simp` to specific lemmas | `simp only [a, b, c]` | reproducible, version-stable |
| Discover what `simp` would use | `simp?` | prints the `simp only` invocation |
| Rewrite *under* a binder or inside a subterm | `simp_rw [h]` or `conv` | `rw` cannot enter binders |
| Simplify by definitional unfolding only | `dsimp` | no rewrites, just `δ`/`β`/`ι`/`η` |
| Rewrite a hypothesis instead of the goal | `rw [h] at h'`, `simp at h'` | append `at <name>` |
| Rewrite both goal and hypotheses | `simp at *` | sledgehammer; use sparingly |
| Move into a subterm of the goal | `conv => …` or `conv at h => …` | precision navigation |
| Turn an equality into a `simp` lemma globally | `attribute [simp] h` | local: `attribute [local simp] h` |

---

### `rw` (rewrite)
Applies a single equality from left to right at the first matching subterm of the goal.
```lean
example (a b : ℕ) (h : a = b) : a + 1 = b + 1 := by
  rw [h]
```
Direction matters: `rw [h]` rewrites `a → b`; `rw [← h]` rewrites `b → a`.
```lean
example (a b : ℕ) (h : a = b) : b + 1 = a + 1 := by
  rw [← h]
```
Multiple rewrites apply in order:
```lean
example (a b c : ℕ) (h₁ : a = b) (h₂ : b = c) : a + 1 = c + 1 := by
  rw [h₁, h₂]
```
**Limit:** `rw` cannot rewrite under a binder (`∀`, `∃`, `λ`). For that, use `simp_rw` or `conv`.

### `simp`
The simplifier. Repeatedly applies every lemma marked `@[simp]` (and any extras you pass) until the goal is in normal form, then closes it if possible.
```lean
example (n : ℕ) : n + 0 + 0 = n := by simp
example (xs : List α) : (xs ++ []).length = xs.length := by simp
```
**Production rule:** never commit a bare `simp` to a long-lived proof. Run `simp?` to extract the lemma list, then replace with `simp only [...]`. The bare form depends on the global `@[simp]` set, which evolves.

Pass extra lemmas:
```lean
example (a b : ℕ) (h : a = b) : a + 0 = b := by simp [h]
```
Pass the *backwards* direction with `←`:
```lean
example (a b c : ℕ) (h : c = a + b) : a + b + 1 = c + 1 := by simp [← h]
```
Disable a `@[simp]` lemma:
```lean
example (a b : ℕ) : a + b = b + a := by simp [Nat.add_comm]   -- always rewrites; may loop
example (a b : ℕ) : a + b = b + a := by simp only [Nat.add_comm]  -- safer
```

### `simp only [...]`
The locked-down form. Applies *only* the listed lemmas, in `simp`'s usual fashion (any direction reachable, until fixed point).
```lean
example (n : ℕ) : n + 0 = n := by simp only [Nat.add_zero]
```
**Idiom:** every committed `simp` should be a `simp only`. Workflow:
1. Write `simp` while developing.
2. Replace with `simp?`; copy the printed `simp only [...]`.
3. Verify the proof still closes.
4. Commit the `simp only` form.

### `simp_rw`
Rewrites with the listed lemmas under binders. Where `rw` refuses, `simp_rw` succeeds.
```lean
example (P Q : ℕ → Prop) (h : ∀ n, P n ↔ Q n) : (∀ n, P n) ↔ (∀ n, Q n) := by
  simp_rw [h]
```
**Distinguishing feature:** `simp_rw [h]` rewrites with `h` exactly the way `simp` would — left-to-right, under binders, repeatedly until no more matches. Unlike `simp [h]`, it does **not** fire any other `@[simp]` lemmas.

### `dsimp`
Definitional simplification only — `δ` (unfold definitions), `β` (beta-reduce `(fun x => e) a`), `ι` (iota for matches/recursors), `η` (eta for functions). No rewriting by equalities.
```lean
example : (fun x : ℕ => x + 1) 5 = 6 := by dsimp; rfl
example (f : ℕ → ℕ) : (fun x => f x) = f := by dsimp
```
**When to reach for `dsimp`:** after a `show`/`change`-style cleanup, or when `simp` is overkill and you only need definitional unfolding to reach a goal that `rfl` will close.

### `conv` (conversion mode)
Navigate into a subterm of the goal, perform rewrites only there, return.
```lean
example (a b c : ℕ) : a + (b + c) = (a + b) + c := by
  conv_lhs => rw [Nat.add_comm b c]
  ring
```
Inside `conv`:
- `lhs` / `rhs` — focus on left/right side of an equality
- `congr` — descend into all child positions
- `ext x` — descend into a binder, naming the bound variable
- `rw [h]` — rewrite in the focused subterm
- `simp only [...]` — simplify the focused subterm

```lean
example (f : ℕ → ℕ) (n : ℕ) : f (n + 0) = f n := by
  conv_lhs => rw [Nat.add_zero]
```
**Idiom:** reach for `conv` when `rw` rewrites the wrong occurrence. `conv_lhs => rw [h]` rewrites only on the left side of an equality goal.

### `at` clauses — rewriting hypotheses
Every rewriting tactic accepts an `at <hyp>` clause to operate on a hypothesis instead of the goal.
```lean
example (a b : ℕ) (h : a + 0 = b) : a = b := by
  simp at h
  exact h

example (a b : ℕ) (h₁ : a = b) (h₂ : a + 1 = 5) : b + 1 = 5 := by
  rw [h₁] at h₂
  exact h₂
```
Use `at *` to mean "everywhere":
```lean
example (a b : ℕ) (h : a = b) : a + 0 = b := by simp [h] at *; exact h
```
**Caution:** `simp at *` is a sledgehammer. It can change hypotheses you don't want changed, including the one you're trying to use. Prefer naming the hypothesis explicitly.

### `attribute [simp]` and `@[simp]`
Mark a lemma so `simp` uses it automatically.
```lean
@[simp] theorem my_zero (n : ℕ) : n + 0 = n := Nat.add_zero n
```
Add to the simp set after the fact:
```lean
attribute [simp] some_existing_lemma
```
Add only locally to a section:
```lean
section
attribute [local simp] some_lemma
-- proofs in this section use the lemma
end
```
**Pitfall:** marking a lemma `@[simp]` in a library affects every downstream user. Reserve global `@[simp]` for confluent, terminating rewrites that produce a smaller / more canonical form. Use `attribute [local simp]` for project-internal preferences.

---

## Common patterns

**Pattern 1 — `simp?` to extract a stable invocation.**
```lean
-- explore
example (n : ℕ) : (n + 0) * 1 = n := by simp?
-- simp? prints: simp only [Nat.add_zero, Nat.mul_one]
-- commit
example (n : ℕ) : (n + 0) * 1 = n := by simp only [Nat.add_zero, Nat.mul_one]
```

**Pattern 2 — `rw` chain followed by `simp` to finish.**
```lean
example (a b : ℕ) (h : a = b + 1) : (a - 1) + 0 = b := by
  rw [h]
  simp
```
The `rw` does the targeted move; `simp` mops up the residue. When stable, replace with `simp only`.

**Pattern 3 — `conv` to target a specific occurrence.**
```lean
-- two occurrences of `a + 0`; rewrite only the first
example (a : ℕ) : (a + 0) + (a + 0) = a + (a + 0) := by
  conv_lhs => rw [show a + 0 = a from Nat.add_zero a]
  -- only the first `a + 0` was rewritten
  rfl
```

**Pattern 4 — `simp_rw` under a quantifier.**
```lean
example (f : ℕ → ℕ) (h : ∀ n, f n = n + 1) : (∀ n, f n = n + 1) := by
  simp_rw [h]
  -- after simp_rw, the goal is ∀ n, n + 1 = n + 1
  intro n; rfl
```

**Pattern 5 — `simp [...]` to absorb hypotheses.**
```lean
example (a b : ℕ) (h : a = 0) : a + b + a = b := by
  simp [h]
```
The hypothesis `h` is added to the simp set for this call only.

**Pattern 6 — `dsimp only` for laser-focused unfolds.**
```lean
def double (n : ℕ) : ℕ := n + n
example (n : ℕ) : double n = n + n := by dsimp only [double]
```
Unfolds exactly the named definitions, nothing else.

---

## Limits and pitfalls

- **`rw` and dependent types.** Rewriting in a goal with dependencies on the rewritten term often fails. Reach for `conv`, `subst`, or restructure the proof.
- **`simp` non-termination.** Two `@[simp]` lemmas that rewrite each other will loop. `simp` has a step bound; on hitting it, it errors. Diagnose with `set_option trace.simp true`.
- **`simp` too aggressive.** A bare `simp` may close a goal "by accident" using lemmas you didn't intend. Always inspect with `simp?` if the closure feels surprising.
- **`rw` order matters.** `rw [h₁, h₂]` first rewrites with `h₁`, then `h₂` against the new goal. If `h₂` no longer matches, you get an error.
- **`conv` exits leave you with the rewritten goal.** A `conv` block returns control to the outer tactic; whatever transformation you applied persists. Plan the next tactic accordingly.
- **`@[simp]` on an `iff`.** `simp` rewrites left-to-right by default. `@[simp] theorem foo : P ↔ Q` makes `simp` rewrite `P` to `Q`. To go the other way, write the lemma with `Q ↔ P` or use the `@[simp ←]` attribute syntax.

---

## See also

- [Library Search and Tactic Suggestion](library-search-and-suggestion.md) — `simp?`, `rw?` are the discovery tactics for this family
- [Arithmetic Decision Procedures](arithmetic-decision-procedures.md) — `ring`, `norm_num`, `field_simp` are specialized rewriters
- [Equality](../lemmas/equality.md) — `Eq.symm`, `Eq.trans`, `congrArg`, `funext` — the lemmas that `rw` and `simp` invoke under the hood
- [Tactic-Adjacent Lemmas](../lemmas/tactic-adjacent.md) — common rewrites that show up in `simp?` output

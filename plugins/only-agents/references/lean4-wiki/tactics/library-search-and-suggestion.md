# Library Search and Tactic Suggestion

[Back to Index](../index.md)

Tactics that find lemmas or proofs for you. The `?` suffix on most of them prints the discovered proof so you can paste it back; the non-suffixed forms run silently and try to close the goal directly. When stuck, ask the elaborator what to try before constructing a proof by hand.

---

## Quick decision table

| Situation | First try | What it produces |
| --- | --- | --- |
| "There must be a lemma for this exact goal" | `exact?` | a single-lemma proof, if one exists |
| Want to peel off the head and see remaining subgoals | `apply?` | candidates closing the goal via `apply f` |
| Goal looks `simp`-able but want to know which lemmas | `simp?` | a `simp only [...]` invocation |
| Need a single rewrite step | `rw?` | suggested rewrites at the goal |
| Heavyweight automation, structural goals | `aesop` | closes; `aesop?` prints the script |
| Many small possibilities, no clear lead | `hint` | runs a bundle in parallel, prints the winner |
| Pure propositional logic | `tauto` | closes any tautology of `∧`, `∨`, `→`, `¬`, `↔` |
| Decidable proposition, finite check | `decide` / `native_decide` | runs the decision procedure |
| Search by lemma *shape*, not by goal | `loogle`, `#find` | pattern-based lemma lookup |

---

### `exact?`
Searches Mathlib for a lemma whose conclusion unifies with the goal and whose hypotheses are available in context. Replaces the older `library_search`.
```lean
example (a b : ℕ) (h : a + b = 0) : a = 0 := by exact?
-- suggests: exact Nat.eq_zero_of_add_eq_zero_right h
```
**Limit:** finds proofs of the form `apply lemma` followed by hypotheses already in scope. It will not chain rewrites or insert intermediate steps. For chains, escalate to `aesop?`.

### `apply?`
Like `exact?`, but lists candidates that close the goal *partially* via `apply f` — useful when you know what the head should be but not the lemma name. Each candidate is reported with the subgoals it would leave behind.
```lean
example (n m : ℕ) (h : n ≤ m) : 2 * n ≤ 2 * m := by apply?
-- suggests: exact Nat.mul_le_mul_left 2 h
```

### `simp?`
Runs `simp` and prints the exact `simp only [...]` invocation it found.
```lean
example (n : ℕ) : n + 0 + 0 = n := by simp?
-- prints: simp only [Nat.add_zero]
```
**Idiom:** always migrate stable `simp` calls to the `simp only [...]` form `simp?` reports. A bare `simp` depends on the global `@[simp]` set and breaks silently when Mathlib adds new lemmas; the `only` form pins the dependency.

### `rw?`
Suggests rewrites that apply at the current goal. Useful when you can almost see the lemma but cannot remember its name.
```lean
example (a b : ℕ) (h : a = b) : a + 1 = b + 1 := by rw?
-- suggests: rw [h]
```
**Tip:** `rw?` operates on the goal; for hypotheses, narrow first with `rw? at h`.

### `aesop` and `aesop?`
General-purpose proof search with a customizable rule set. Tries case splits, applies registered safe lemmas, normalizes with `simp`, and recurses. The `?` form prints the script it found so you can replace the search with the literal proof.
```lean
example {p q : Prop} (h : p ∧ q) : q ∧ p := by aesop
example (xs : List α) (h : xs ≠ []) : xs.head? ≠ none := by aesop
```
Customize Aesop with attributes:
- `@[aesop safe]` — always tried (no backtracking on it)
- `@[aesop unsafe 50%]` — tried with backtracking, weighted
- `@[aesop norm]` — used as a normalization step
- (See Aesop docs for the full taxonomy — `forward`, `destruct`, etc.)

### `hint`
Runs a curated bundle of common tactics in parallel and accepts the first one that closes the goal. Quick "what should I try?" when no single tactic stands out.
```lean
example (a b : ℕ) (h : a < b) : a ≤ b := by hint
-- might land on: exact Nat.le_of_lt h, or omega, or aesop
```
**Production note:** `hint` is for exploration. Once it finds a proof, replace the call with the specific tactic it picked — `hint`'s bundle changes across versions.

### `tauto`
Closes any propositional tautology built from `∧`, `∨`, `→`, `¬`, `↔`, `True`, `False`. Faster and more focused than `aesop` on pure propositional work.
```lean
example (p q : Prop) : p ∧ q ↔ q ∧ p := by tauto
example (p q r : Prop) (h : p → q) (h' : q → r) : p → r := by tauto
```
**Limit:** does not handle quantifiers — for those, `aesop` or manual `intro` / `exact`.

### `decide` and `native_decide`
Not search tactics, but worth listing here: any decidable proposition can be closed by running its decision procedure.
```lean
example : 100 ∣ 1000 := by decide
example : Nat.Prime 1000003 := by native_decide
```
Full treatment: see [Arithmetic Decision Procedures](arithmetic-decision-procedures.md).

### `loogle` and `#find`
Lemma search by *pattern*, not by goal. Asks "which lemmas have this shape?" — invaluable when `exact?` does not see the lemma you want, or when you are not yet ready to commit to a goal.
```lean
-- at the top level of a Lean file
#find _ + _ ≤ _ + _
-- via the loogle web service or editor integration
loogle Nat.gcd ?_ ?_ = ?_
```
`loogle` is a separate service (https://loogle.lean-lang.org); `#find` is a Mathlib command that runs in the file. Both accept holes (`?_` or `_`) and return matching lemmas with their full signatures.

---

## Common patterns

**Pattern 1 — `exact?` first, always.** Before constructing a proof manually, run `exact?`. If a single Mathlib lemma exists, you have it for free.
```lean
example (a b c : ℕ) (h : a ≤ b) (h' : b ≤ c) : a ≤ c := by exact?
-- suggests: exact le_trans h h'
```

**Pattern 2 — migrate `simp` to `simp only` via `simp?`.** Naked `simp` is fragile; replace it with the printed `simp only [...]` once stable.
```lean
-- step 1: simp?
example : (1 : ℕ) + 0 = 1 := by simp?
-- step 2: simp? prints: simp only [Nat.add_zero]
-- step 3: lock it in
example : (1 : ℕ) + 0 = 1 := by simp only [Nat.add_zero]
```

**Pattern 3 — `aesop?` to bootstrap, then prune.** When `aesop` works, run `aesop?` to extract the script, then trim it to the minimum needed. The result is a readable, version-stable proof.

**Pattern 4 — `intro` first, then `apply?`.** When the head of the goal is `→` or `∀`, expose the body before searching:
```lean
example (P Q : Prop) (h : P → Q) : P → Q := by
  intro hp
  apply?
  -- suggests: exact h hp
```

**Pattern 5 — guess by naming convention when search fails.** Mathlib follows strict conventions; `exact?` will miss lemmas if elaboration cannot specialize the universe / type. When stuck, guess:
- `<op>_<property>` — `add_comm`, `mul_assoc`, `or_comm`
- `<namespace>.<op>_<other>` — `Nat.add_zero`, `List.length_append`
- relations as words — `_le_`, `_lt_`, `_iff_`, `_eq_`
- `_of_` reads "from" — `eq_of_lt_succ_of_le` is "equality from `<succ` and `≤`"
- `_left` / `_right` for asymmetry — `add_le_add_left`, `mul_pos_iff_of_pos_right`

Typing `Nat.<thing you want>` and letting completion list options is often faster than `exact?`.

**Pattern 6 — `loogle` / `#find` for pattern queries.** When you can describe the *shape* of the lemma but the goal isn't yet in that shape:
```lean
#find _ * (_ + _) = _ * _ + _ * _   -- finds distributivity lemmas
#find Nat.gcd _ (_ + _)              -- finds gcd-of-sum lemmas
```

---

## Limits and pitfalls

- **`exact?` does not chain.** Single-lemma applications only. For two-step proofs, escalate to `aesop?` or write the chain manually.
- **`apply?` is slow with many premises.** Add structure first (`intro`, `rcases`) so it has a narrower goal to match against.
- **`simp?` output drifts.** A `simp?`-derived `simp only` is correct *now*; if the proof breaks after a Mathlib bump, re-run `simp?`.
- **`aesop` can succeed by accident.** Always inspect the printed script — sometimes the search closes a trivial reformulation rather than the intended lemma.
- **`hint`'s bundle is nondeterministic across versions.** Pick the suggestion you like and write it directly; do not commit `hint` calls to long-lived proofs.
- **Search tactics ignore implicit-universe pitfalls.** If `exact?` cannot find an obvious lemma, the issue is often that the elaborator cannot pin a universe variable — try `@`-explicit application or unify the universe by hand.

---

## See also

- [Arithmetic Decision Procedures](arithmetic-decision-procedures.md) — the targeted decision tactics that often follow a `?` suggestion
- [Tactic-Adjacent Lemmas](../lemmas/tactic-adjacent.md) — lemmas that frequently appear in `exact?` / `apply?` output
- [Equality](../lemmas/equality.md) — `Eq.symm`, `Eq.trans`, `congrArg`, `funext` — the lemmas behind `rw?` suggestions

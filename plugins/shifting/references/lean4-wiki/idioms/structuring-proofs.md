# Structuring Proofs

[Back to Index](../index.md)

Tactics that turn a wall of automation into a readable argument. Mathlib proofs use a small structural vocabulary — `have`, `suffices`, `show`, `calc`, bullets — to break work into steps that document themselves. Reach for them whenever a proof passes a handful of lines without a named milestone, or when a single tactic application would hide the argument.

---

## Quick reference

| You want to... | Tactic | Mental model |
| --- | --- | --- |
| Name an intermediate fact and use it later | `have h : T := proof` | "Establish T, call it h, continue." |
| Reduce the goal to a single named target, prove that target after | `suffices h : T by ...` | "It would suffice to know T; finish using it, then prove T." |
| Re-display the goal as a definitionally equal form | `show T` | "Re-state the goal as T (for the reader and the elaborator)." |
| Force the goal to a specific defeq form | `change T` | Like `show`, stricter on what counts as "equal." |
| Introduce a local abbreviation | `let x := e` | "Bind x to e for the rest of the proof." |
| Introduce + capture the equation | `set x := e with hx` | Like `let` but also folds occurrences and gives `hx`. |
| Build a transitive chain of (in)equalities | `calc x R y := … _ R z := …` | "Step-by-step from x to z, composing relations." |
| Focus on one subgoal | `· tactics` or `case <name> => tactics` | "These tactics belong to this branch only." |
| Provide a term with holes for Lean to fill | `refine` | Like `exact` but with `?_` holes for subgoals. |
| Close with whatever is in scope | `assumption` | "Some hypothesis equals this goal." |
| Close a refl-by-construction goal | `rfl`, `trivial` | Literally nothing to do. |

---

### `have`
Names an intermediate result. The proof of the named fact appears on the right; downstream tactics refer to it by name.
```lean
example (a b c : ℕ) (h : a + b = c) (h' : c = 10) : a + b = 10 := by
  have hc : a + b = 10 := h.trans h'
  exact hc
```
**Idiom:** prefer the named form `have h : T := proof` over anonymous `have := proof`. The anonymous form binds `this`, which is awkward to reference and discourages reuse.

### `suffices`
Inverts the proof flow: state a target you wish were sufficient, finish the goal assuming it, then prove the target.
```lean
example (a b : ℝ) (h : a^2 + b^2 = 0) : a = 0 := by
  suffices ha2 : a^2 = 0 by
    exact sq_eq_zero_iff.mp ha2
  nlinarith [sq_nonneg a, sq_nonneg b]
```
The `suffices` line is the road sign: it tells the reader where the proof is going *before* the harder step appears. Use it when the goal is in a shape no lemma matches but a related shape (the `suffices` target) has an obvious lemma.

### `show`
Re-displays the goal as a definitionally equal form — useful after `simp` chews the goal up, or to remind both reader and elaborator what is being proved.
```lean
example (n : ℕ) : 2 * n = n + n := by
  show 2 * n = n + n
  ring
```
**Limit:** the new form must be definitionally equal. For non-defeq reformulations, use `suffices`.

### `change`
Like `show`, but the new form must be definitionally equal up to **unfolding only** — no rearrangement of instance arguments, no commutative reshuffles. Strictest of the "rewrite the goal display" tactics.
```lean
example (n : ℕ) : (fun x => x + 1) n = n + 1 := by
  change n + 1 = n + 1
  rfl
```

### `let` and `set`
Local abbreviations.
- `let x := e` introduces a definition that unfolds when needed.
- `set x := e with hx` introduces the same definition, **folds existing occurrences** of `e` to `x` in the goal and hypotheses, and binds the captured equation as `hx`.
```lean
example (a b : ℕ) (h : a + b = 10) : a + b + 1 = 11 := by
  set s := a + b with hs
  -- now h : s = 10 (folded), hs : s = a + b, goal : s + 1 = 11
  omega
```
**Idiom:** prefer `set` over `let` whenever you also want the equation as a usable hypothesis; the folding behavior alone often pays for itself by simplifying the goal display.

### `calc`
Transitive chains of equalities and inequalities. Each step states the next term and the proof connecting it to the previous one. The `_` placeholder stands for the previous right-hand side.
```lean
example (a b c : ℝ) (h₁ : a ≤ b) (h₂ : b < c) : a < c :=
  calc a ≤ b := h₁
    _ < c := h₂

example (n : ℕ) : (n + 1)^2 = n^2 + 2*n + 1 := by
  calc (n + 1)^2
      = (n + 1) * (n + 1) := by ring
    _ = n*n + n + n + 1   := by ring
    _ = n^2 + 2*n + 1     := by ring
```
**Idiom:** mix relations freely — `≤`, `<`, `=`, `≥`, `>`, `↔` can be chained, and the result takes the strictest relation that survives. `a = b` followed by `b < c` yields `a < c`.

### Bullets and `case` focus
After a tactic produces multiple goals, each branch must be closed in turn. Bullets scope tactics to one branch:
```lean
example (n : ℕ) : n = 0 ∨ 0 < n := by
  rcases Nat.eq_zero_or_pos n with h | h
  · left; exact h
  · right; exact h
```
Or refer to a goal by name with `case`:
```lean
example (n : ℕ) : n = 0 ∨ 0 < n := by
  rcases Nat.eq_zero_or_pos n with h | h
  case inl h => exact Or.inl h
  case inr h => exact Or.inr h
```
**Idiom:** prefer bullets for short, ordered branches and `case` for longer or order-independent ones. Lean does **not** infer scope from indentation alone — without `·` or `case`, all tactics flow into the first remaining goal.

### `refine` versus `exact`
- `exact e` provides a complete proof term.
- `refine e` provides a proof term with `?_` holes; each hole becomes a subgoal.
```lean
example (a b : ℕ) (ha : 0 < a) (hb : 0 < b) : 0 < a * b := by
  refine Nat.mul_pos ?_ ?_
  · exact ha
  · exact hb
```
**Idiom:** use `refine` to commit to a lemma's *shape* while leaving its arguments as goals — particularly useful with non-trivial premises that need their own proofs.

### Closing tactics
- `rfl` — closes goals that hold by definitional equality.
- `trivial` — `rfl`, `True.intro`, or simple `assumption`-style finishes.
- `assumption` — closes the goal if any hypothesis matches it.
```lean
example : 1 + 1 = 2 := rfl
example : True := trivial
example (P : Prop) (h : P) : P := by assumption
```

---

## Common patterns

**Pattern 1 — forward chain of `have`s.** Build the conclusion step by step, each step named:
```lean
example (a b c : ℕ) (h₁ : a ≤ b) (h₂ : b ≤ c) (h₃ : c ≤ 10) : a ≤ 10 := by
  have hac : a ≤ c := le_trans h₁ h₂
  have h10 : a ≤ 10 := le_trans hac h₃
  exact h10
```
Use sparingly. Over-naming buries the argument — save names for facts referenced more than once or facts the reader will want flagged.

**Pattern 2 — backward plan with `suffices`.** When a strong lemma almost matches but the goal is one transform away:
```lean
example (a b : ℝ) (h : (a - b)^2 = 0) : a = b := by
  suffices h' : a - b = 0 by linarith
  exact pow_eq_zero_iff (n := 2) (by norm_num) |>.mp h
```
The `suffices` line tells the reader the strategy in one line; the rest is mechanical.

**Pattern 3 — calc for multi-step (in)equality reasoning.** Calc shines when each step uses a different lemma:
```lean
example (a b c : ℝ) (hab : a ≤ b) (hbc : b ≤ c) (hc : c < 10) : a < 10 :=
  calc a ≤ b := hab
    _ ≤ c := hbc
    _ < 10 := hc
```
Without `calc`, the same proof reads as `lt_of_le_of_lt (le_trans hab hbc) hc` — correct but opaque.

**Pattern 4 — bullets disciplined by indentation.** After a case split or `refine` with multiple holes, every subgoal gets a bullet at the same indentation:
```lean
example (n : ℕ) : n + 0 = n ∧ 0 + n = n := by
  refine ⟨?_, ?_⟩
  · exact Nat.add_zero n
  · exact Nat.zero_add n
```

**Pattern 5 — `set` to compress a recurring expression.** When the same expression appears repeatedly, name it once:
```lean
example (a b : ℝ) (h : 0 < a^2 + b^2 + 1) : 0 < (a^2 + b^2 + 1) * 2 := by
  set d := a^2 + b^2 + 1 with hd
  -- h : 0 < d, hd : d = a^2 + b^2 + 1, goal : 0 < d * 2
  positivity
```

**Pattern 6 — `show` to restore readability after `simp`.** When `simp` leaves the goal in an opaque form:
```lean
example (n : ℕ) (h : n = 0) : n + n = 0 := by
  simp [h]
  -- goal might display as 0 = 0 or similar
```
A `show` after `simp` confirms the intended display, especially when reviewing the proof later.

---

## Limits and pitfalls

- **Anonymous `have` produces `this`.** `have := proof` works but binds the inaccessible name `this`. Always name with `have h : T := …`.
- **`show` vs `change`.** `show` is forgiving about defeq; `change` is strict. If `show` does not work, `change` will not either — the issue is your defeq reasoning, not the tactic choice.
- **`calc` step direction.** Each `_ R y := proof` step proves `<previous> R y`, not `<previous> = y`. Mismatching the relation is a type error caught by the elaborator; chaining mixed relations composes them, taking the strictest.
- **Bullet drift.** A bullet (`·`) opens scope until the next bullet at the same level. Wrongly nested bullets produce confusing errors — when in doubt, rebracket with explicit `(by …)`.
- **`refine` and instance arguments.** `refine` does not insert `?_` for instance arguments by default; use explicit `@`-application if you need to leave an instance goal as a hole.
- **`set` direction.** The `with hx` clause names the equation `x = e` (new abbreviation equals old expression). Folding rewrites occurrences of `e` to `x` in the goal — when this folds *too aggressively*, fall back to `let` or write the equation manually with `have`.

---

## See also

- [Connectives](../lemmas/connectives.md) — `And.intro`, `Or.inl`/`inr`, `Iff.intro` — the constructors that bullets often peel apart
- [Equality](../lemmas/equality.md) — `Eq.symm`, `Eq.trans`, `congrArg`, `funext` — the lemmas behind `calc` and `rw`
- [Library Search and Tactic Suggestion](../tactics/library-search-and-suggestion.md) — `exact?` and `apply?` populate the bodies of the structural skeletons above
- [Arithmetic Decision Procedures](../tactics/arithmetic-decision-procedures.md) — the closing tactics that finish the leaves of a structured proof

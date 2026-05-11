# Term Mode vs Tactic Mode

[Back to Index](../index.md)

Lean has two ways to write a proof: as a **term** (a literal expression of the right type) or as a **tactic block** (a script that constructs the term). They produce identical compiled output; the choice is a stylistic and ergonomic one. Term mode is concise and explicit; tactic mode is malleable and composable. Knowing when to reach for each is a hallmark of fluent Lean writing.

---

## Quick decision

| Situation | Use | Why |
| --- | --- | --- |
| Proof is a single lemma application | term mode `:= lemma_name args` | shortest, most direct |
| Proof is a single function application or λ | term mode `:= fun x => …` | term mode is the natural shape |
| Proof needs more than ~3 steps | tactic mode `:= by …` | tactic blocks scale; term-mode chains get illegible fast |
| Proof needs decisions / case splits | tactic mode | term mode forces eager elaboration |
| Proof depends on automation (`simp`, `omega`, `ring`) | tactic mode | these tactics have no clean term-mode form |
| Proof is a witness for `∃` / `Σ` | term mode `⟨witness, proof⟩` | the anonymous constructor is purpose-built |
| Proof is a one-liner inside a larger expression | term mode | doesn't drag a `by` block into the middle of a term |
| Building infrastructure (instances, definitions) | term mode where possible | term mode is more inspectable for the elaborator |

---

## The two modes

### Term mode
```lean
theorem add_comm_zero (n : ℕ) : 0 + n = n + 0 := Nat.add_comm 0 n
```
The proof is the term `Nat.add_comm 0 n`, which has type `0 + n = n + 0`. No tactic block, no script.

### Tactic mode
```lean
theorem add_comm_zero (n : ℕ) : 0 + n = n + 0 := by
  rw [Nat.add_comm]
```
The proof is a script. The `by` keyword opens a tactic block that ends with a goal of the right type. The elaborator runs the script and produces a term behind the scenes.

### Mixing
You can move freely between modes mid-proof:
```lean
example (a b : ℕ) (h : a = b) : a + 1 = b + 1 := by
  rw [show a = b from h]
```
The `show … from …` is term mode inside a tactic block. Conversely:
```lean
example : 0 + 5 = 5 := by simp
example : 0 + 5 = 5 := (by simp : 0 + 5 = 5)
```
The second example uses `by` to produce a term inline.

---

## Term-mode idioms

### Direct lemma application
```lean
example (n : ℕ) : 0 + n = n := Nat.zero_add n
example (a b : ℕ) (h : a = b) : a + 1 = b + 1 := congrArg (· + 1) h
```

### λ for proofs of `→` and `∀`
```lean
example : ∀ n : ℕ, n + 0 = n := fun n => Nat.add_zero n
example (P Q : Prop) (hp : P) (h : P → Q) : Q := h hp
```

### Anonymous constructor for products / records / `Exists`
```lean
example : ∃ n : ℕ, n > 5 := ⟨6, by norm_num⟩
example (a b : ℕ) (ha : 0 < a) (hb : 0 < b) : 0 < a ∧ 0 < b := ⟨ha, hb⟩
```

### `Or.inl` / `Or.inr` for disjunctions
```lean
example (n : ℕ) (h : n = 0) : n = 0 ∨ 0 < n := Or.inl h
```

### Method-call syntax (`.`-notation)
When `h : Iff p q`, write `h.mp` for the forward direction, `h.mpr` for backward. When `h : a < b`, write `h.le` for "downgrade to ≤".
```lean
example (a b : ℕ) (h : a < b) : a ≤ b := h.le
example (p q : Prop) (h : p ↔ q) (hp : p) : q := h.mp hp
```
This is sometimes the fastest way to write a one-step proof.

### `show` for type ascription in term mode
```lean
example : 1 + 1 = 2 := show 1 + 1 = 2 from rfl
```
Used when the elaborator needs a hint about the intended type — often after `match` or in expressions where the type is otherwise ambiguous.

### `match` in term mode
```lean
example (n : ℕ) : Bool :=
  match n with
  | 0 => true
  | _ + 1 => false
```
Term-mode pattern matching, useful for short, exhaustive functions.

---

## Tactic-mode idioms (covered elsewhere in detail)

For the full catalogue see [Structuring Proofs](structuring-proofs.md), [Destructuring](destructuring.md), and the various tactic entries. Briefly:
- `intro`, `rintro` — introduce hypotheses
- `exact`, `refine`, `apply` — close or shape the goal with a term
- `rw`, `simp`, `simp_rw` — rewrite
- `cases`, `induction`, `obtain`, `rcases` — split / destructure
- `have`, `suffices`, `show`, `change`, `let`, `set` — structural moves

---

## Hybrid patterns

### `(by tac : T)` — anonymous tactic-produced term
```lean
example : ∃ n : ℕ, n > 100 := ⟨101, (by norm_num : (101 : ℕ) > 100)⟩
```
When you need to slot a tactic-produced proof into a term-mode context, wrap it in `(by … : T)`.

### `show T from e` — type-directed term
```lean
example (a b : ℕ) (h : a = b) : a + 1 = b + 1 := by
  rw [show a = b from h]
```
Useful for inserting a witness into a tactic call without naming it.

### `by exact e` — collapse trivially
Sometimes the elaborator infers something better in tactic mode than in pure term mode (instance resolution, universe handling). `by exact e` is a workaround:
```lean
example (a : ℕ) : a = a := by exact rfl
```
Almost always equivalent to plain `rfl`; reach for it only when pure term mode fails type inference.

### Conversely: `(fun h => …)` for short tactic blocks
```lean
-- tactic mode
example (P : Prop) (h : P) : P := by exact h
-- term mode (shorter)
example (P : Prop) (h : P) : P := h
-- term mode with intro
example : ∀ P : Prop, P → P := fun _ h => h
```

---

## When term mode wins

**One-line lemma applications.** `:= Nat.add_zero n` is shorter and clearer than `:= by exact Nat.add_zero n`.

**Witnesses.** `⟨6, by norm_num⟩` for `∃ n, n > 5` is the natural shape — no `use 6; norm_num` ceremony.

**Compositional proofs.** When a proof reads as "apply A, then B, then C", term mode lets you write `C (B (A x))` directly.

**Inside expressions.** A proof embedded in a larger term — say, a record literal — wants to be a term, not a tactic block.

**Definitions and instances.** Definitional content, like the body of an `instance` or a `def`, is naturally term-mode.

```lean
instance : AddCommMonoid MyType where
  add := fun a b => …
  add_assoc := fun a b c => …   -- term mode for short proofs
  add_comm := fun a b => by simp [...]  -- tactic mode when needed
```

---

## When tactic mode wins

**Anything more than three steps.** Term-mode chains of `Eq.trans (Eq.symm h₁) (h₂.trans h₃)` are unreadable. Tactic mode names each step.

**Branching proofs.** Case splits, induction, `if-then-else` on hypotheses — all want tactic mode. Term-mode `match` exists but rarely produces clean proofs.

**Automation-heavy.** `simp`, `omega`, `linarith`, `ring`, `norm_num`, `decide` — these have no usable term-mode form.

**Iteratively developed proofs.** Tactic mode gives you intermediate goal states. Term mode forces you to commit to the entire structure up front. Develop in tactic mode, optionally compress to term mode at the end if the result fits.

**Proofs that need to be edited.** Adding a step to `Eq.trans (Eq.symm h₁) h₂` means restructuring the entire term. Adding a step to a tactic block means inserting a line.

---

## Common patterns

**Pattern 1 — term mode for the body, tactic mode for hard parts.**
```lean
def myFun (n : ℕ) (h : n > 0) : ℕ := n - 1

theorem myFun_lt (n : ℕ) (h : n > 0) : myFun n h < n := by
  unfold myFun
  omega
```
The `def` body is term mode; the theorem proof needs `omega`, so it's tactic mode.

**Pattern 2 — `⟨…⟩` for witness, `by` for the property.**
```lean
example : ∃ n : ℕ, n > 5 ∧ n < 10 := ⟨7, by norm_num, by norm_num⟩
```
Term-mode tuple, tactic-mode proofs inside.

**Pattern 3 — develop in tactic mode, compress to term mode if cheap.**
```lean
-- developed
example (a b : ℕ) (h : a = b) : f a = f b := by rw [h]
-- compressed (rfl trick when possible)
example (a b : ℕ) (h : a = b) : f a = f b := h ▸ rfl
-- or
example (a b : ℕ) (h : a = b) : f a = f b := congrArg f h
```
Pick the form that reads best; don't compress at the cost of clarity.

**Pattern 4 — `.mp` / `.mpr` over rewriting an `Iff`.**
```lean
-- tactic
example (p q : Prop) (h : p ↔ q) (hp : p) : q := by rw [h] at hp; exact hp
-- term mode (shorter)
example (p q : Prop) (h : p ↔ q) (hp : p) : q := h.mp hp
```

**Pattern 5 — `▸` (triangle) for rewrite-by-equality in term mode.**
```lean
example (a b : ℕ) (h : a = b) (hp : P a) : P b := h ▸ hp
```
The `▸` operator is term-mode rewriting: `h ▸ x` is "x, with `h` applied to rewrite the goal".

---

## Limits and pitfalls

- **Term-mode chains rot.** A 5-step term-mode proof becomes unmaintainable; switch to tactic mode well before that point.
- **`by` inside a term elaborates eagerly.** A `(by simp : T)` inside a record literal causes `simp` to run during elaboration of that record — slow and brittle. Prefer naming the lemma and using it term-mode.
- **Term mode and instance resolution.** Term mode sometimes fails to resolve instances that tactic mode finds (because tactic mode runs the elaborator with more flexibility). When in doubt and stuck, switch to `by exact`.
- **`fun h => … ` and `fun (h : T) => …` differ.** In ambiguous contexts, the latter form forces the type. Don't omit the annotation when the elaborator can't infer.
- **Method-call `.` syntax requires the method to exist.** `h.le` works because `LT.lt` has a `.le` method (via `le_of_lt`). For your own types, you must register methods or use plain function calls.
- **Mixing `▸` with dependent types is fragile.** `▸` does motive inference, which can fail or pick a non-obvious motive. Prefer `Eq.mpr` / `cast` with explicit typing for dependent rewrites.

---

## See also

- [Structuring Proofs](structuring-proofs.md) — `have`, `show`, `suffices` are the tactic-mode versions of term-mode shape control
- [Destructuring](destructuring.md) — `obtain` ↔ `⟨…⟩` are tactic / term-mode duals
- [Library Search and Tactic Suggestion](../tactics/library-search-and-suggestion.md) — `exact?` proposes term-mode proofs even from tactic mode
- [Equality](../lemmas/equality.md) — `Eq.symm`, `Eq.trans`, `congrArg` — the term-mode primitives behind `rw`

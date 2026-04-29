# Structural Tactics

[Back to Index](../index.md)

Tactics that decompose a goal by its structure rather than its content. `congr` reduces an equality of compound terms to equalities of components; `funext` proves functions equal by proving them pointwise equal; `ext` is the user-extensible umbrella; `gcongr` handles monotonic congruence for inequalities; `mono` finds a monotonicity proof for a goal of monotonic shape. These tactics are how you "peel" a goal one layer at a time when no single rewrite or lemma application closes it.

---

## Quick decision table

| Goal shape | Tactic | What it does |
| --- | --- | --- |
| `f a = f b` (or `f a₁ a₂ = f b₁ b₂`) | `congr` | reduces to `a = b` (or `a₁ = b₁ ∧ a₂ = b₂`) |
| `f = g` for functions | `funext x` | reduces to `∀ x, f x = g x` |
| `s = t` for sets, `μ = ν` for measures, `e = e'` for any extensional type | `ext x` | reduces to a pointwise/element-wise equality |
| `f a ≤ f b` where `f` is monotone | `gcongr` | reduces to `a ≤ b` |
| `f a₁ b₁ ≤ f a₂ b₂` for monotone `f` in both args | `gcongr` | reduces to `a₁ ≤ a₂` and `b₁ ≤ b₂` |
| Any monotonicity goal `Monotone (f ∘ g)`, `Monotone (· + a)`, etc. | `mono` | composes monotonicity lemmas |
| Equality up to congruence with a side condition | `congr 1`, `congr! n` | controls the congruence depth |
| Equality of subtypes / quotients | `Subtype.ext`, `Quotient.sound` | type-specific extension principles |
| Two `Iff` shapes are propositionally equal | `propext` | promotes Iff to Eq for Props |

---

### `congr`
Reduces `f a₁ … aₙ = f b₁ … bₙ` to subgoals `a₁ = b₁`, `…`, `aₙ = bₙ`. The function head must syntactically match on both sides.
```lean
example (f : ℕ → ℕ) (a b : ℕ) (h : a = b) : f a = f b := by
  congr
  exact h

example (a b c d : ℕ) (h₁ : a = c) (h₂ : b = d) : a + b = c + d := by
  congr
```
**Idiom:** `congr` is greedy by default — it descends as deep as it can, sometimes producing trivial-looking subgoals like `Nat.succ = Nat.succ`. Use `congr 1` or `congr 2` to limit the depth:
```lean
example (a b : ℕ) (h : a = b) : (a, 1) = (b, 1) := by
  congr 1   -- one level: produces a = b, 1 = 1; the second is closed by rfl
  exact h
```
Use `congr!` for a smarter / less-greedy variant in modern Mathlib.

### `funext`
Proves `f = g` by proving `f x = g x` for all `x`. The fundamental extension principle for functions.
```lean
example : (fun n : ℕ => n + 0) = (fun n => n) := by
  funext n
  simp
```
**Idiom:** name the variable: `funext x y` for two-argument functions, `funext ⟨a, b⟩` to destructure the binder.

### `ext`
The user-extensible umbrella for all "pointwise equality" tactics. Each `@[ext]`-tagged lemma adds a new case to `ext`. For sets it produces `∀ x, x ∈ s ↔ x ∈ t`; for functions it produces `∀ x, f x = g x`; for measures it produces equality on measurable sets; etc.
```lean
example (s t : Set ℕ) (h : ∀ x, x ∈ s ↔ x ∈ t) : s = t := by
  ext x
  exact h x

example (f g : ℕ → ℕ) (h : ∀ n, f n = g n) : f = g := by
  ext n
  exact h n
```
**Idiom:** `ext` is almost always the first move on an extensional equality. If you see `s = t`, `f = g`, `μ = ν` and want to prove it pointwise, start with `ext`.

### `congr!` (modern Mathlib)
Smarter cousin of `congr` with better heuristics — handles dependent types, applies extensionality lemmas automatically, and accepts depth/closing-tactic arguments.
```lean
example (a b : ℕ) (h : a = b) : (fun x => x + a) = (fun x => x + b) := by
  congr! with x
  exact h
```
The `with x` clause names introduced binders, mirroring `funext`.

### `gcongr` — generalized congruence for inequalities
Where `congr` reduces equalities, `gcongr` reduces inequalities by traversing monotone operations.
```lean
example (a b c d : ℕ) (h₁ : a ≤ c) (h₂ : b ≤ d) : a + b ≤ c + d := by gcongr

example (a b : ℝ) (h : 0 ≤ a) (h' : a ≤ b) : a^2 ≤ b^2 := by
  gcongr
```
**How `gcongr` knows:** lemmas tagged `@[gcongr]` register that `f` is monotone in a particular argument. The user can extend it by tagging their own lemmas. Without a `@[gcongr]` lemma for the operation, `gcongr` will not descend.

```lean
example (s t : Finset ℕ) (h : s ⊆ t) (f : ℕ → ℕ) : ∑ x ∈ s, f x ≤ ∑ x ∈ t, f x := by
  -- requires nonnegativity of f, omitted here
  sorry
```

### `mono` — monotonicity composition
Proves a goal of monotonicity shape by composing monotonicity lemmas. Less powerful than `gcongr` for nested goals, but useful for top-level statements like `Monotone (f ∘ g)`.
```lean
example (f g : ℕ → ℕ) (hf : Monotone f) (hg : Monotone g) : Monotone (f ∘ g) := by
  mono
```
**Note:** `mono` and `gcongr` have overlapping use cases. `gcongr` is the modern preference for inequality goals; `mono` is sometimes the better fit for proving a `Monotone f` predicate directly.

### Type-specific extensionality
Many types have their own `_ext` lemma named by convention.

```lean
example (s : {n : ℕ // n > 5}) (t : {n : ℕ // n > 5}) (h : s.val = t.val) : s = t :=
  Subtype.ext h

example (f g : LinearMap ℝ V W) (h : ∀ v, f v = g v) : f = g := LinearMap.ext h
```
**Idiom:** if `ext` doesn't recognize your type, look for `<TypeName>.ext` directly. Most structural types have one.

### `propext`
Converts `↔` to `=` for propositions. Rarely written by hand — usually invoked by `simp` or `rw` automatically.
```lean
example (p q : Prop) (h : p ↔ q) : p = q := propext h
```
**When to know about it:** `simp` rewriting an `Iff` works precisely because `propext` lifts it to `=`. Goals in classical logic that mix `=` and `↔` may need a manual `propext`.

---

## Common patterns

**Pattern 1 — `ext` first on an extensional equality.**
```lean
example (s t u : Set ℕ) (h₁ : s = u) (h₂ : t = u) : s = t := by
  ext x
  rw [h₁, h₂]
```

**Pattern 2 — `funext` to align two functions before further reasoning.**
```lean
example : (fun n : ℕ => n + 1) = Nat.succ := by
  funext n
  rfl
```

**Pattern 3 — `congr` to peel one layer.**
```lean
example (xs ys : List ℕ) (h : xs = ys) : xs.length + 1 = ys.length + 1 := by
  congr 1
```
The `1` keeps `congr` from descending past the addition into `Nat.succ` machinery.

**Pattern 4 — `gcongr` for nested inequalities.**
```lean
example (a b c d : ℝ) (h₁ : 0 ≤ a) (h₂ : a ≤ b) (h₃ : 0 ≤ c) (h₄ : c ≤ d) :
    a * c ≤ b * d := by
  gcongr
```
`gcongr` finds `mul_le_mul` (or its variants) automatically because it's tagged `@[gcongr]`.

**Pattern 5 — pair `ext` with `simp` for set/measure equalities.**
```lean
example (s : Set ℕ) : s ∪ s = s := by
  ext x
  simp [Set.mem_union]
```

**Pattern 6 — `congr!` over `congr` for cleaner output.**
When `congr` produces strange residual goals (often involving universe or instance arguments), try `congr!`:
```lean
example (n : ℕ) (h : n = 5) : Fin (n + 1) = Fin 6 := by
  congr!
```

---

## Limits and pitfalls

- **`congr` and definitional equality.** `congr` requires the function heads to *syntactically* match. `f x = g x` will not yield to `congr` unless `f` and `g` are the same head — use `funext` or unfolding first.
- **`congr` over `congr` over `congr`.** Greedy descent can produce many tiny goals. If you want one-level peeling, write `congr 1`.
- **`ext` requires a registered lemma.** For a custom type, you must tag your extensionality lemma `@[ext]`, or call it by name (`MyType.ext`).
- **`gcongr` needs `@[gcongr]` tags.** A `gcongr` failure on a custom operation means no monotonicity lemma is registered. Register one or fall back to `apply <lemma_name>`.
- **`mono` is finicky.** Prefer `gcongr` for inequalities; reach for `mono` mainly when the goal is itself a `Monotone f` predicate.
- **`funext` over a dependent function.** When `f : ∀ x, P x → Q x`, `funext x hx` introduces both — but the resulting goal must be provable for arbitrary `x` and `hx`, which is sometimes too strong.
- **Subtype extensionality wants the value, not the proof.** `Subtype.ext` reduces `(⟨a, _⟩ : {x // P x}) = ⟨b, _⟩` to `a = b` — proof irrelevance handles the rest.

---

## See also

- [Equality](../lemmas/equality.md) — `Eq.symm`, `Eq.trans`, `congrArg`, `funext` — the term-mode forms of these tactics
- [Functions](../lemmas/functions.md) — `Function.Injective`, `Function.Surjective`, function composition lemmas
- [Sets](../lemmas/sets.md) — `Set.ext`, `Set.mem_union`, the lemmas `ext` invokes for set goals
- [Simp and Rewriting](simp-and-rewriting.md) — `simp` often closes the residual subgoals after `ext` / `congr` peels a layer

# Arithmetic Decision Procedures

[Back to Index](../index.md)

Tactics that close arithmetic goals automatically. Picking the right one matters: `omega` is bulletproof on linear integer/`Nat` goals and useless on rationals; `linarith` extends to ordered fields but will not multiply hypotheses; `nlinarith` does products at the cost of being slower and less predictable. Reach for the cheapest tactic that is still powerful enough — escalating only when it fails.

---

## Quick decision table

| Goal shape | First try | If that fails |
| --- | --- | --- |
| Linear arithmetic over `ℤ` or `ℕ`, possibly with `%`, `/`, integer literals | `omega` | restructure (out of scope means out of scope) |
| Linear arithmetic over `ℚ`, `ℝ`, or any ordered field | `linarith` | `nlinarith` |
| Hypotheses need to be multiplied together | `nlinarith [sq_nonneg …]` | `polyrith`, manual lemmas |
| Pure polynomial identity in a commutative (semi)ring | `ring` | `ring_nf` then `linarith` / `nlinarith` |
| Polynomial equality requiring a combination of equation hypotheses | `linear_combination` | `polyrith` |
| Numeric literal arithmetic (`2 + 3 = 5`, `Nat.Prime 97`) | `norm_num` | `decide` |
| Decidable proposition, small | `decide` | `native_decide` |
| Decidable proposition, large search space | `native_decide` | restructure |
| Nonneg / positivity from the structure of an expression | `positivity` | `nlinarith [...]` |
| Equality in an additive abelian group (no multiplication) | `abel` | `abel_nf` |
| Goal contains denominators over a field | `field_simp` then `ring` / `linarith` | `field_simp [hyp]; nlinarith` |

---

### `omega`
Decision procedure for **linear arithmetic over `ℤ` and `ℕ`** (Presburger arithmetic). Handles `+`, `-`, multiplication by integer literals, integer `/`, `%`, ordering, and equality. Complete in scope: if the goal is genuinely in linear integer arithmetic, `omega` will close it.
```lean
example (a b : ℕ) (h : a + 2 * b ≤ 10) (h' : 3 ≤ a) : b ≤ 3 := by omega
example (n : ℤ) (h : n % 2 = 1) : (n + 1) % 2 = 0 := by omega
example (k : ℕ) (h : k < 5) : k ≤ 4 := by omega
```
**Limit:** multiplication of two variables is out of scope. `(h : a * b > 0) ⊢ 0 < a * b` will not be closed by `omega` — escalate to `nlinarith` or split cases.

### `linarith`
Linear arithmetic over **ordered (semi)rings**. Adds, subtracts, and scales hypotheses by positive constants, then looks for a contradiction or a derived inequality. Will not multiply hypotheses together.
```lean
example (x y : ℝ) (h₁ : x ≤ 3) (h₂ : y ≤ 5) : x + y ≤ 8 := by linarith
example (a : ℚ) (h : 2 * a < 7) : a < 4 := by linarith
```
**Feeding nonlinear facts:** `linarith` accepts a hint list. This is the standard idiom for getting it past a square term:
```lean
example (x y : ℝ) : 2 * x * y ≤ x^2 + y^2 := by linarith [sq_nonneg (x - y)]
```

### `nlinarith`
`linarith` with a preprocessing step that multiplies pairs of hypotheses and adds `sq_nonneg` facts. Closes many polynomial inequalities; pays for it in time and predictability.
```lean
example (x y : ℝ) (hx : 0 ≤ x) (hy : 0 ≤ y) : 0 ≤ x * y + x^2 + y^2 := by nlinarith
example (a b : ℝ) : a^2 + b^2 ≥ 2 * a * b := by nlinarith [sq_nonneg (a - b)]
```
**When `nlinarith` is slow** narrow the search by passing only the lemmas it needs: `nlinarith [sq_nonneg expr, named_lemma]`.

### `polyrith`
Polynomial arithmetic via Gröbner bases. Closes commutative-ring equalities by finding a polynomial combination of equation hypotheses. Slower than `ring` but handles cases that require combining hypotheses, which `ring` alone cannot.
```lean
example (x y : ℚ) (h : x + y = 1) (h' : x * y = -2) : x^2 + y^2 = 5 := by polyrith
```
**Reproducibility:** `polyrith` prints the `linear_combination` proof it found; paste that in to make the proof not depend on the external solver.

### `linear_combination`
Closes a polynomial equality by giving an explicit combination of hypothesis equalities. Where `ring` proves identities and `polyrith` searches, `linear_combination` is what you write when you know the combination.
```lean
example (x y : ℝ) (h : x + y = 5) (h' : x - y = 1) : x = 3 := by linear_combination (h + h') / 2
example (a b c : ℤ) (h : a = b + c) : 2 * a = 2 * b + 2 * c := by linear_combination 2 * h
```
The provided expression must reduce to `goal - 0` modulo `ring`.

### `positivity`
Proves `0 ≤ e` or `0 < e` by structural recursion on `e`: sums of nonneg are nonneg, products of pos are pos, even powers are nonneg, factorials, absolute values, norms, etc. Faster and more targeted than `nlinarith` for plain positivity goals.
```lean
example (x : ℝ) (h : 0 < x) : 0 < x^2 + x + 1 := by positivity
example (n : ℕ) : 0 < n.factorial + 1 := by positivity
example (a : ℝ) : 0 ≤ |a| + 1 := by positivity
```
**Limit:** does not use arbitrary hypotheses — only the structure of the expression. If you need to combine inequalities to get nonnegativity, escalate to `nlinarith`.

### `norm_num`
Normalizes and evaluates numeric expressions involving literals. Closes goals about concrete numbers: arithmetic, comparisons, primality, gcd, divisibility.
```lean
example : (2 : ℝ)^10 = 1024 := by norm_num
example : Nat.Prime 97 := by norm_num
example : Nat.gcd 12 18 = 6 := by norm_num
example : (5 : ℚ) ≠ 0 := by norm_num
```
**Composes well:** `simp [foo, bar]; norm_num` is a frequent pattern when literal arithmetic remains after simplification. `norm_num` is also extensible — extensions add support for new families (primes, sqrt, etc.).

### `decide` and `native_decide`
Close any **decidable** proposition by running its decision procedure.
- `decide` runs in the kernel — slow on large computations, but adds nothing to the trust base.
- `native_decide` compiles to native code and runs there — fast, but adds `Lean.ofReduceBool` to the trusted code.
```lean
example : (List.range 10).sum = 45 := by decide
example : Nat.Prime 1000003 := by native_decide
example : ∀ n : Fin 5, n.val < 5 := by decide
```
**Rule of thumb:** start with `decide`; switch to `native_decide` only when `decide` times out and the enlarged TCB is acceptable for the project.

### `ring` and `ring_nf`
Commutative (semi)ring identities. `ring` closes the goal if both sides are equal as ring expressions; `ring_nf` normalizes both sides to a canonical form (useful when the goal is an inequality or you need to feed a normalized expression to another tactic).
```lean
example (x y : ℝ) : (x + y)^2 = x^2 + 2 * x * y + y^2 := by ring
example (a b : ℤ) : (a - b) * (a + b) = a^2 - b^2 := by ring
example (x : ℝ) (h : x^2 + 2*x + 1 ≤ 0) : (x + 1)^2 ≤ 0 := by ring_nf at h ⊢; exact h
```
**Limit:** does not use hypotheses. If you need to use an equality hypothesis to close a ring goal, reach for `linear_combination` or `polyrith`.

### `field_simp`
Clears denominators in a field — multiplies through by every nonzero term it can identify (using nonzero hypotheses in scope or passed explicitly), then leaves a denominator-free goal that you typically close with `ring` or `linarith`.
```lean
example (x : ℝ) (hx : x ≠ 0) : 1 / x + 1 / x = 2 / x := by field_simp
example (a b : ℝ) (ha : a ≠ 0) (hb : b ≠ 0) : (a + b) / (a * b) = 1 / a + 1 / b := by
  field_simp
  ring
```
**Pass nonzero hypotheses explicitly** when they are not in the local context: `field_simp [ha, hb]`.

### `abel` and `abel_nf`
The `ring`/`ring_nf` analogues for **additive abelian groups** (no multiplication). Closes (or normalizes) equalities involving `+`, `-`, `0`, scalar `Nat`/`Int` multiplication.
```lean
example {G : Type*} [AddCommGroup G] (a b c : G) : a + b - c - b + c = a := by abel
example {G : Type*} [AddCommGroup G] (a b : G) : 2 • a + b - a = a + b := by abel
```

---

## Common patterns

**Pattern 1 — feed nonlinear facts into a linear engine.** `linarith` cannot square hypotheses, but it accepts pre-squared facts:
```lean
example (x y : ℝ) : 2 * x * y ≤ x^2 + y^2 := by linarith [sq_nonneg (x - y)]
example (a b c : ℝ) : a^2 + b^2 + c^2 ≥ a*b + b*c + c*a := by
  linarith [sq_nonneg (a - b), sq_nonneg (b - c), sq_nonneg (c - a)]
```

**Pattern 2 — clear denominators, then close with `ring` or `linarith`.** Goals over `ℝ` / `ℚ` with `/` rarely yield to `nlinarith` directly — clear first:
```lean
example (a b : ℝ) (ha : a > 0) (hb : b > 0) : a / b + b / a ≥ 2 := by
  rw [ge_iff_le, ← sub_nonneg]
  field_simp
  rw [div_nonneg_iff]
  left
  constructor
  · nlinarith [sq_nonneg (a - b)]
  · positivity
```

**Pattern 3 — `by_cases` when a tactic cannot see the structure.** Some goals are easy on each branch but neither tactic sees the dichotomy:
```lean
example (a : ℝ) (h : a ≠ 0) : a * a > 0 := by
  rcases lt_or_gt_of_ne h with h | h
  · nlinarith
  · nlinarith
```

**Pattern 4 — `norm_num` plus `simp` for goals with literals after rewriting.** `simp` reduces structure, `norm_num` finishes the arithmetic:
```lean
example (n : ℕ) (h : n = 7) : n^2 + 3 * n + 1 = 71 := by simp [h]; norm_num
```

**Pattern 5 — escalate from `decide` to `native_decide` only on demand.** `decide` first, native if and only if it times out:
```lean
-- decide is fine for small finite checks
example : ∀ n : Fin 10, 2 * n.val < 20 := by decide
-- native_decide for larger numbers, accepting the bigger TCB
example : Nat.Prime 1000003 := by native_decide
```

---

## See also

- [Inequalities](../theorems/inequalities.md) — Cauchy-Schwarz, AM-GM, Holder, the named lemmas these tactics often call internally
- [Tactic-Adjacent Lemmas](../lemmas/tactic-adjacent.md) — small lemmas that complement these procedures
- [Powers & Exponents](../lemmas/powers-exponents.md) — manual `^` lemmas when `ring` does not apply (e.g. non-commutative settings)
- [Order Relations](../lemmas/order-relations.md) — the inequality lemmas that `linarith` and `nlinarith` build on

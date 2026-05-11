# Mathlib Naming Conventions

[Back to Index](../index.md)

Mathlib follows a strict naming convention. Once you internalize the rules, you can guess lemma names with surprisingly high accuracy — often faster than running `exact?`. This is the cheat sheet.

---

## The core rule

A Mathlib lemma name reads as a sentence: **subject — verb — object — of qualifiers**. Words are separated by `_`. The conclusion goes first, hypotheses come later, joined with `_of_` or `_iff_`.

```
add_le_add        — "add ≤ add"               (a ≤ b → c ≤ d → a + c ≤ b + d)
add_le_add_left   — "add ≤ add, on the left"  (b ≤ c → a + b ≤ a + c)
le_of_lt          — "≤, from <"               (a < b → a ≤ b)
sq_eq_zero_iff    — "sq = 0, iff"             (a^2 = 0 ↔ a = 0)
```

---

## The vocabulary

### Operations
| Symbol | Word | Notes |
| --- | --- | --- |
| `+` | `add` | |
| `-` | `sub` | binary subtraction |
| `-` (unary) | `neg` | additive inverse |
| `*` | `mul` | |
| `/` | `div` | |
| `^` | `pow` | |
| `⁻¹` | `inv` | multiplicative inverse |
| `0` | `zero` | |
| `1` | `one` | |
| `‖·‖` | `norm` | |
| `\|·\|` | `abs` | |
| `√` | `sqrt` | |
| `Σ` (finite) | `sum` | |
| `∏` (finite) | `prod` | |

### Relations
| Symbol | Word | Direction notes |
| --- | --- | --- |
| `=` | `eq` | |
| `≠` | `ne` | |
| `≤` | `le` | "less than or equal" |
| `<` | `lt` | "less than" |
| `≥` | `ge` | rare in lemma names; prefer `le` with sides swapped |
| `>` | `gt` | rare in lemma names; prefer `lt` with sides swapped |
| `↔` | `iff` | |
| `→` | `of` | "from" — used in conclusion-first names |
| `∣` | `dvd` | divisibility |
| `∈` | `mem` | membership |
| `⊆` | `subset` | |

### Quantifiers and structure
| Symbol | Word |
| --- | --- |
| `∀` | `forall` (rare in names; usually elided) |
| `∃` | `exists` (rare in names; usually elided) |
| `¬` | `not` |
| `∧` | `and` |
| `∨` | `or` |
| `⊥`, `False` | `false` |
| `⊤`, `True` | `true` |

### Type-class hints
| Hint | Word in name |
| --- | --- |
| In a group | `_group` (rare) — usually implicit |
| In a field | `_field` (rare) — usually implicit |
| In a `LinearOrder` | qualifies via `le`/`lt` working bidirectionally |
| Closed under `+` | `_add` in name |
| Identifies a positive case | `_pos` |
| Identifies a nonneg case | `_nonneg` |
| Identifies a nonzero case | `_ne_zero` |

---

## The grammar

### Conclusion-first
A name describes what the lemma *concludes*, then what hypotheses it needs.

```
add_le_add_left  : b ≤ c → a + b ≤ a + c
                   ─────────  ─────────────
                   "left side adding"  conclusion: addition preserves ≤ on the left
```

The lemma `add_le_add_left` proves `b ≤ c → a + b ≤ a + c`. Read the name as "(adding) on the (left) preserves (≤)". Argument order in the name reflects the *result*, not the hypothesis.

### `_of_` for hypothesis chaining
When the lemma's conclusion is short and its hypothesis is a different operation, link them with `_of_`:

```
le_of_lt           : a < b → a ≤ b
                     ─────   ─────
                     "≤ from <"
                     hypothesis after _of_, conclusion before
```

`_of_` reads "from" — `eq_of_le_of_le` is "equality from ≤ and ≤" (i.e. `a ≤ b → b ≤ a → a = b`, antisymmetry).

### `_iff_` for biconditionals
```
sq_eq_zero_iff     : a^2 = 0 ↔ a = 0
sub_eq_zero_iff_eq : a - b = 0 ↔ a = b
```
The `_iff_` separator splits the two sides of the biconditional.

### `_left` / `_right` for asymmetry
When an operation has a "side" — addition's left vs right argument, equality on left vs right of an `iff` — the name records it.
```
add_le_add_left  : b ≤ c → a + b ≤ a + c   -- a is on the left
add_le_add_right : b ≤ c → b + a ≤ c + a   -- a is on the right
mul_pos_iff_of_pos_left : 0 < a → (0 < a * b ↔ 0 < b)
```

### `_pos`, `_nonneg`, `_neg`, `_nonpos`, `_ne_zero`, `_ne`
```
add_pos    : 0 < a → 0 < b → 0 < a + b
add_nonneg : 0 ≤ a → 0 ≤ b → 0 ≤ a + b
mul_pos    : 0 < a → 0 < b → 0 < a * b
sq_nonneg  : 0 ≤ a^2
ne_of_lt   : a < b → a ≠ b
```

### `_self`, `_zero`, `_one`
For lemmas where one argument is fixed at a special value:
```
add_zero  : a + 0 = a
zero_add  : 0 + a = a
mul_one   : a * 1 = a
mul_zero  : a * 0 = 0
sub_self  : a - a = 0
add_self  : a + a = 2 * a    -- (when defined)
```

### Direction of an equality / `iff`
By convention, the LHS of the equation appears first in the name.
```
add_comm    : a + b = b + a       -- LHS is `a + b`
mul_assoc   : a * b * c = a * (b * c)  -- LHS is the unbracketed form
```
For an `iff`, the side that's "less canonical" or "uses extra structure" comes first:
```
sq_eq_zero_iff : a^2 = 0 ↔ a = 0   -- a^2 = 0 first; "a = 0" is the simpler form
```

### Namespace prefixes
Lemmas about a specific type are namespaced. Inside the namespace, the type's name is dropped from the lemma:
```
namespace Nat
theorem add_zero (n : ℕ) : n + 0 = n := …  -- referenced as Nat.add_zero
```

Standard top-level namespaces:
- `Nat`, `Int`, `Rat`, `Real`, `Complex`
- `List`, `Array`, `Finset`, `Set`
- `Function`, `Equiv`
- `Group`, `Ring`, `Field`, `Module`, `Submodule`, `LinearMap`
- `Topology`, `MetricSpace`, `Continuous`
- `Measure`, `MeasureTheory`, `ProbabilityTheory`

Inside a namespace, drop the type name; outside, include it: `Nat.add_zero` becomes `add_zero` inside `namespace Nat`.

---

## Examples by reading

| Name | Reads as | Statement |
| --- | --- | --- |
| `add_comm` | "add commutes" | `a + b = b + a` |
| `mul_assoc` | "mul associates" | `a * b * c = a * (b * c)` |
| `add_le_add` | "add (preserves) ≤ on add" | `a ≤ b → c ≤ d → a + c ≤ b + d` |
| `Nat.add_zero` | "Nat add zero" | `n + 0 = n` (in `Nat`) |
| `le_of_lt` | "≤ from <" | `a < b → a ≤ b` |
| `lt_of_le_of_ne` | "< from ≤ and ≠" | `a ≤ b → a ≠ b → a < b` |
| `pow_succ` | "pow successor" | `a ^ (n+1) = a^n * a` |
| `eq_of_sub_eq_zero` | "= from sub = 0" | `a - b = 0 → a = b` |
| `sq_nonneg` | "sq is nonneg" | `0 ≤ a^2` |
| `Finset.sum_add_distrib` | "Finset sum, add distributes" | `∑ x ∈ s, (f x + g x) = ∑ x ∈ s, f x + ∑ x ∈ s, g x` |
| `List.length_append` | "List length of append" | `(xs ++ ys).length = xs.length + ys.length` |
| `Function.Injective.comp` | "Function injective composition" | `Injective f → Injective g → Injective (f ∘ g)` |
| `Set.subset_union_left` | "Set ⊆ union, on the left" | `s ⊆ s ∪ t` |

---

## Predicates and their lemmas

A common pattern: a predicate `Foo` has lemmas named `Foo.<conclusion>` and `<conclusion>_iff_<predicate>`.

```
Even             — predicate
Even.add         : Even a → Even b → Even (a + b)         -- closure under +
even_iff_two_dvd : Even n ↔ 2 ∣ n                          -- characterization
```

```
Continuous              — predicate
Continuous.add          : Continuous f → Continuous g → Continuous (f + g)
Continuous.comp         : Continuous g → Continuous f → Continuous (g ∘ f)
continuous_iff_continuousAt : Continuous f ↔ ∀ x, ContinuousAt f x
```

When you see a predicate, look for the namespace `<Predicate>.<closure_law>` for closure under operations.

---

## Composing names

When you can't find a lemma, try composing words by the rules:
1. State the conclusion in mathematical notation.
2. Replace symbols with their words.
3. Add hypotheses with `_of_` if needed.
4. Prefix with the namespace if it's about a specific type.
5. Add `_left` / `_right` if the lemma is asymmetric.

**Example:** "if `a ≤ b` and `c ≤ d`, then `a + c ≤ b + d`."
- Conclusion: `a + c ≤ b + d` → `add_le_add`
- Hypotheses are the same operation, no `_of_` needed.
- Both arguments matter, so no `_left` / `_right`.
- Result: `add_le_add` ✓

**Example:** "if `0 < a`, then `a ≠ 0`."
- Conclusion: `a ≠ 0` → `ne_zero`
- Hypothesis: `0 < a` → `_of_pos`
- Wait — `pos` already implies "0 < a". So the lemma might be `ne_of_pos` or `Pos.ne_zero` or `ne_of_gt` (since `0 < a` is `0 < a`).
- Mathlib has `ne_of_gt : a < b → a ≠ b`, so the lemma is essentially `(h : 0 < a).ne'` — using a method on `Pos`.

(This last example shows the limit: composition gets you close, but anonymous-constructor methods like `.ne'` and `.le.trans` are sometimes the actual answer. When in doubt, fall back to `exact?`.)

---

## Common pitfalls

- **`_le_` vs `_lt_`.** The relation in the *name* matches the relation in the *conclusion*, not the hypothesis. `lt_of_le_of_lt` proves a `<` (conclusion) from a `≤` and a `<` (hypotheses).
- **Direction of `_iff_`.** Mathlib's convention is "less canonical" → "more canonical". `sq_eq_zero_iff` is `a^2 = 0 ↔ a = 0`, not the reverse. To use it forward (`a = 0 → a^2 = 0`), use `.mpr`.
- **Implicit type-class arguments.** `add_comm` may not apply if the type is not a `CommMonoid`. The lemma name doesn't tell you the typeclass — but if `exact?` fails despite a perfect-looking name match, check the typeclass hierarchy.
- **Mismatched namespaces.** `Nat.add_zero` lives inside `Nat`; `add_zero` outside it (with the `AddZeroClass` typeclass) is a different lemma. Both prove `n + 0 = n`, but for different types.
- **`add_self` vs `two_mul`.** Some natural lemma names don't exist because the canonical form prefers a different shape. `a + a = 2 * a` is `two_mul a` (read backwards: "two mul"). Don't waste time guessing `add_self` if `two_mul` exists.

---

## See also

- [Library Search and Tactic Suggestion](../tactics/library-search-and-suggestion.md) — `exact?`, `loogle`, `#find` for when name-guessing fails
- Each entry under [Lemmas](../index.md#lemmas) — these conventions are the rationale behind every lemma name in the wiki

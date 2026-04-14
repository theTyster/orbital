# Lists

[Back to Index](../index.md)

Lemmas for `List` operations: append, length, map, reverse, membership, and filter.

---

### `List.append_nil`
Appending the empty list: `l ++ [] = l`
```lean
example (l : List α) : l ++ [] = l := List.append_nil l
```

### `List.nil_append`
Prepending the empty list: `[] ++ l = l`
```lean
example (l : List α) : [] ++ l = l := List.nil_append l
```

### `List.append_assoc`
Associativity of list append.
```lean
example (a b c : List α) : a ++ b ++ c = a ++ (b ++ c) := List.append_assoc a b c
```

### `List.length_append`
Length of concatenation: `(a ++ b).length = a.length + b.length`
```lean
example (a b : List α) : (a ++ b).length = a.length + b.length := List.length_append a b
```

### `List.length_nil`
Length of the empty list is zero.
```lean
example : ([] : List α).length = 0 := List.length_nil
```

### `List.length_cons`
Length of a cons: `(a :: l).length = l.length + 1`
```lean
example (a : α) (l : List α) : (a :: l).length = l.length + 1 := List.length_cons a l
```

### `List.map_map`
Composing two maps: `(l.map f).map g = l.map (g ∘ f)`
```lean
example (f : α → β) (g : β → γ) (l : List α) :
    (l.map f).map g = l.map (g ∘ f) := List.map_map g f l
```

### `List.map_id`
Mapping the identity function is the identity.
```lean
example (l : List α) : l.map id = l := List.map_id l
```

### `List.reverse_reverse`
Reversing twice yields the original list.
```lean
example (l : List α) : l.reverse.reverse = l := List.reverse_reverse l
```

### `List.mem_cons`
Membership in a cons: `a ∈ b :: l ↔ a = b ∨ a ∈ l`
```lean
example (a b : α) (l : List α) : a ∈ b :: l ↔ a = b ∨ a ∈ l := List.mem_cons
```

### `List.mem_append`
Membership in an append: `a ∈ l₁ ++ l₂ ↔ a ∈ l₁ ∨ a ∈ l₂`
```lean
example (a : α) (l₁ l₂ : List α) : a ∈ l₁ ++ l₂ ↔ a ∈ l₁ ∨ a ∈ l₂ := List.mem_append
```

### `List.filter_append`
Filtering distributes over append.
```lean
example (p : α → Bool) (l₁ l₂ : List α) :
    (l₁ ++ l₂).filter p = l₁.filter p ++ l₂.filter p := List.filter_append p l₁ l₂
```

### `List.foldl`
Left fold: `[a, b, c].foldl f init = f (f (f init a) b) c`
```lean
example : [1, 2, 3].foldl (· + ·) 0 = 6 := rfl
```

### `List.foldr`
Right fold: `[a, b, c].foldr f init = f a (f b (f c init))`
```lean
example : [1, 2, 3].foldr (· + ·) 0 = 6 := rfl
```

### `List.zip`
Zips two lists into a list of pairs, truncating to the shorter length.
```lean
example : List.zip [1, 2] ['a', 'b'] = [(1, 'a'), (2, 'b')] := rfl
```

### `List.take_append_drop`
Taking and dropping partition a list: `l.take n ++ l.drop n = l`
```lean
example (n : Nat) (l : List α) : l.take n ++ l.drop n = l := List.take_append_drop n l
```

### `List.length_take`
Length of take: `(l.take n).length = min n l.length`
```lean
example (n : Nat) (l : List α) : (l.take n).length = min n l.length := List.length_take n l
```

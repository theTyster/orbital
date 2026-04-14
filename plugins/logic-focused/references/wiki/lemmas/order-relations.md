# Order Relations

[Back to Index](../index.md)

Generic lemmas for `≤`, `<`, `min`, and `max` on ordered types.

---

### `le_refl`
Reflexivity of `≤`.
```lean
example [Preorder α] (a : α) : a ≤ a := le_refl a
```

### `le_trans`
Transitivity of `≤`.
```lean
example [Preorder α] (a b c : α) (h1 : a ≤ b) (h2 : b ≤ c) : a ≤ c := le_trans h1 h2
```

### `le_antisymm`
Antisymmetry of `≤`: if `a ≤ b` and `b ≤ a` then `a = b`.
```lean
example [PartialOrder α] (a b : α) (h1 : a ≤ b) (h2 : b ≤ a) : a = b := le_antisymm h1 h2
```

### `lt_irrefl`
No element is strictly less than itself.
```lean
example [Preorder α] (a : α) (h : a < a) : False := lt_irrefl a h
```

### `lt_trans`
Transitivity of `<`.
```lean
example [Preorder α] (a b c : α) (h1 : a < b) (h2 : b < c) : a < c := lt_trans h1 h2
```

### `lt_of_le_of_lt`
If `a ≤ b` and `b < c` then `a < c`.
```lean
example [Preorder α] (a b c : α) (h1 : a ≤ b) (h2 : b < c) : a < c := lt_of_le_of_lt h1 h2
```

### `le_of_lt`
Strict inequality implies non-strict.
```lean
example [Preorder α] (a b : α) (h : a < b) : a ≤ b := le_of_lt h
```

### `le_of_eq`
Equality implies `≤`.
```lean
example [Preorder α] (a b : α) (h : a = b) : a ≤ b := le_of_eq h
```

### `lt_of_lt_of_eq`
If `a < b` and `b = c` then `a < c`.
```lean
example [Preorder α] (a b c : α) (h1 : a < b) (h2 : b = c) : a < c := lt_of_lt_of_eq h1 h2
```

### `min_le_left`
The minimum is at most the left argument.
```lean
example [LinearOrder α] (a b : α) : min a b ≤ a := min_le_left a b
```

### `min_le_right`
The minimum is at most the right argument.
```lean
example [LinearOrder α] (a b : α) : min a b ≤ b := min_le_right a b
```

### `le_max_left`
The left argument is at most the maximum.
```lean
example [LinearOrder α] (a b : α) : a ≤ max a b := le_max_left a b
```

### `le_max_right`
The right argument is at most the maximum.
```lean
example [LinearOrder α] (a b : α) : b ≤ max a b := le_max_right a b
```

# Record (Named Compound Terms)

**Problem**: Accessing fields in compound terms by position (arg/3) is fragile and unreadable.

```prolog
:- use_module(library(record)).

:- record point(x: float = 0.0, y: float = 0.0, z: float = 0.0).

example :-
    default_point(P0),
    set_x_of_point(3.0, P0, P1),
    set_y_of_point(4.0, P1, P2),
    point_x(P2, X),
    point_y(P2, Y),
    Dist is sqrt(X*X + Y*Y),
    format("Distance from origin: ~f~n", [Dist]).
```

**When to use**: When you have structured data but dicts feel too heavy, or you want compile-time field name checking.

---

**See also**: [Dicts](dicts.md) (heavier-weight alternative with runtime field access), [Option Lists](option-lists.md) (for optional parameters rather than structured data).

# Definite Clause Grammars (DCG)

**Problem**: Writing parsers by manually threading input/output lists is verbose and error-prone.

```prolog
% Parse "hello world" as greeting
greeting --> [hello], name.
name --> [world].
name --> [prolog].

% Usage:
% ?- phrase(greeting, [hello, world]).
% true.
```

**Parsing with structure building**:
```prolog
:- use_module(library(dcg/basics)).

% Parse "123+456" into an expression tree
expr(plus(A, B)) --> number(A), "+", number(B).

% Usage:
% ?- phrase(expr(Tree), "123+456").
% Tree = plus(123, 456).
```

**Pushback notation** (`remainder//1`):
```prolog
% Peek at remaining input without consuming
peek(Rest), Rest --> remainder(Rest).
```

**When to use**: Parsing DSLs, protocols, config files, natural language fragments. Any time you're processing sequential input.

**Pitfall**: DCGs hide the difference list threading — if you need to debug, use `listing/1` to see the expanded clauses.

---

**See also**: [Modules](modules.md) (DCG rules can be placed in modules and imported), [PCRE](pcre.md) (for simpler pattern matching where a full grammar is overkill).

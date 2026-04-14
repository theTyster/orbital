# PCRE (Regular Expressions)

**Problem**: Prolog's built-in string matching is limited to atom/sub_atom operations.

```prolog
:- use_module(library(pcre)).

% Simple match
?- re_match("^[a-z]+$", "hello").
% true.

% Capture groups
?- re_matchsub("(?P<year>\\d{4})-(?P<month>\\d{2})", "2026-04-14", Sub, []).
% Sub = re_match{0:"2026-04", year:"2026", month:"04"}.

% Replace
?- re_replace("world", "Prolog", "hello world", Result).
% Result = "hello Prolog".
```

**When to use**: Input validation, log parsing, text extraction — anything where DCGs are overkill.

---

**See also**: [DCG](dcg.md) (for more complex parsing that needs structure building).

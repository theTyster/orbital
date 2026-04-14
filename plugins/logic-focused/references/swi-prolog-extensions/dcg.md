# Definite Clause Grammars (DCG)

**Problem**: Writing parsers by manually threading input/output lists is verbose and error-prone. DCGs let you write grammar rules directly in Prolog.

## Core API

| Predicate / Notation | Purpose |
|---|---|
| `phrase(RuleName, Input)` | Parse `Input` using the DCG rule `RuleName` |
| `phrase(RuleName, Input, Rest)` | Parse `Input`, unify unparsed remainder with `Rest` |
| `-->` | Define a grammar rule |
| `[terminal]` | Match a literal terminal |
| `{ Goal }` | Inline a Prolog goal (no input consumed) |
| `,` pushback notation | Push tokens back onto the input after matching |

## phrase/2 and phrase/3

`phrase/2` expects the entire input to be consumed. `phrase/3` lets you access the remaining input:

```prolog
greeting --> [hello], name.
name --> [world].
name --> [prolog].

%% phrase/2 — must consume all input
?- phrase(greeting, [hello, world]).
% true.

?- phrase(greeting, [hello, world, extra]).
% false.   (leftover input)

%% phrase/3 — get the remainder
?- phrase(greeting, [hello, world, extra, tokens], Rest).
% Rest = [extra, tokens].
```

## Inline Prolog Goals with { }

Curly braces embed arbitrary Prolog without consuming input. Useful for guards, computation, and side effects:

```prolog
:- use_module(library(dcg/basics)).

% Parse a positive integer
positive_int(N) --> integer(N), { N > 0 }.

%% ?- phrase(positive_int(N), "42", []).
%% N = 42.

%% ?- phrase(positive_int(N), "-5", []).
%% false.
```

## Pushback Notation

The comma after a rule body pushes tokens back onto the input, allowing lookahead without consuming:

```prolog
%% Peek at next token without consuming it
peek(Token), [Token] --> [Token].

%% Parse tokens until we see "stop", without consuming "stop"
collect([]), [stop] --> [stop].
collect([H|T]) --> [H], collect(T).

%% ?- phrase(collect(Items), [a, b, c, stop, rest], Rest).
%% Items = [a, b, c], Rest = [stop, rest].
```

## library(dcg/basics) — Common Parsers

```prolog
:- use_module(library(dcg/basics)).

%% Predefined rules from dcg/basics:
%%   integer(N)    — parse a signed integer
%%   float(F)      — parse a floating-point number
%%   number(N)     — parse integer or float
%%   string(Codes) — parse a sequence of non-whitespace codes
%%   blanks        — skip whitespace
%%   blank         — skip one whitespace char
%%   whites        — skip spaces and tabs (not newlines)
%%   eos           — match end of input
%%   remainder(R)  — unify R with all remaining input
```

## Practical Example: Arithmetic Expression Parser

A complete recursive-descent parser that handles operator precedence and builds an AST:

```prolog
:- use_module(library(dcg/basics)).

%% Grammar:
%%   expr   -> term (('+' | '-') term)*
%%   term   -> factor (('*' | '/') factor)*
%%   factor -> '(' expr ')' | number

expr(E) --> term(T), expr_rest(T, E).

expr_rest(Acc, E) --> [+], term(T), { A is Acc + T }, expr_rest(A, E).
expr_rest(Acc, E) --> [-], term(T), { A is Acc - T }, expr_rest(A, E).
expr_rest(E, E) --> [].

term(T) --> factor(F), term_rest(F, T).

term_rest(Acc, T) --> [*], factor(F), { A is Acc * F }, term_rest(A, T).
term_rest(Acc, T) --> [/], factor(F), { F =\= 0, A is Acc / F }, term_rest(A, T).
term_rest(T, T) --> [].

factor(E) --> ['('], expr(E), [')'].
factor(N) --> [N], { number(N) }.

%% Helper: tokenize a string into a list for the DCG
tokenize(String, Tokens) :-
    atom_chars(String, Chars),
    exclude(=(' '), Chars, NoSpaces),
    maplist(to_token, NoSpaces, Tokens).

to_token(C, N) :- char_type(C, digit(N)), !.
to_token(C, A) :- atom_chars(A, [C]).

%% Usage with character-code lists (simpler approach):
eval_expr(String, Result) :-
    string_codes(String, Codes),
    phrase(calc_expr(Result), Codes).

calc_expr(E) --> calc_term(T), calc_expr_rest(T, E).

calc_expr_rest(Acc, E) --> "+", calc_term(T),
    { A is Acc + T }, calc_expr_rest(A, E).
calc_expr_rest(Acc, E) --> "-", calc_term(T),
    { A is Acc - T }, calc_expr_rest(A, E).
calc_expr_rest(E, E) --> [].

calc_term(T) --> calc_factor(F), calc_term_rest(F, T).

calc_term_rest(Acc, T) --> "*", calc_factor(F),
    { A is Acc * F }, calc_term_rest(A, T).
calc_term_rest(Acc, T) --> "/", calc_factor(F),
    { F =\= 0, A is Acc / F }, calc_term_rest(A, T).
calc_term_rest(T, T) --> [].

calc_factor(E) --> "(", calc_expr(E), ")".
calc_factor(N) --> number(N).

%% ?- eval_expr("3+4*2", R).
%% R = 11.
%% ?- eval_expr("(3+4)*2", R).
%% R = 14.
```

## Practical Example: Simple Key-Value Config Parser

```prolog
:- use_module(library(dcg/basics)).

%% Parse lines like "key = value\n" into key-value pairs
config(Pairs) --> blanks, config_lines(Pairs).

config_lines([K-V|Rest]) --> config_line(K, V), config_lines(Rest).
config_lines([]) --> eos.

config_line(Key, Value) -->
    string_without("=\n", KeyCodes), { atom_codes(Key, KeyCodes) },
    "=",
    string_without("\n", ValCodes), { atom_codes(Value, ValCodes) },
    ( "\n" | eos ).

%% ?- phrase(config(Pairs), "host=localhost\nport=8080\n").
%% Pairs = [host-localhost, port-'8080'].
```

**When to use**: Parsing DSLs, protocols, config files, natural language fragments. Any time you're processing sequential input.

**Pitfall**: DCGs hide the difference list threading — if you need to debug, use `listing/1` to see the expanded clauses.

---

**See also**: [Modules](modules.md) (DCG rules can be placed in modules and imported), [PCRE](pcre.md) (for simpler pattern matching where a full grammar is overkill), [Coroutining](coroutining.md) (freeze/2 can defer DCG processing until input is available).

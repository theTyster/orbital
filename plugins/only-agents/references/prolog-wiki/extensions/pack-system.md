# Pack System (Third-Party Libraries)

**Problem**: Not everything is built-in. The pack system lets you install community libraries.

## Core API

| Predicate | Purpose |
|---|---|
| `pack_install(Name)` | Install a pack from the registry |
| `pack_install(Name, Options)` | Install with options (e.g., version, URL) |
| `pack_list_installed` | List all installed packs |
| `pack_search(Query)` | Search the pack registry by keyword |
| `pack_info(Name)` | Show detailed info about an installed pack |
| `pack_remove(Name)` | Uninstall a pack |
| `pack_rebuild(Name)` | Recompile a pack's foreign libraries |
| `pack_upgrade(Name)` | Upgrade a pack to latest version |

## Example: Basic Usage

```prolog
% Install a pack
?- pack_install(mavis).      % Type checking
?- pack_install(func).       % Functional programming
?- pack_install(dcg_utils).  % Extra DCG utilities

% List installed packs
?- pack_list_installed.

% Search for packs
?- pack_search(csv).

% Get details about a pack
?- pack_info(mavis).

% Remove a pack
?- pack_remove(func).
```

## Example: Version Pinning and Git Sources

```prolog
% Install a specific version
?- pack_install(mavis, [version('0.2.3')]).

% Install from a git URL
?- pack_install(my_pack, [url('https://github.com/user/my_pack.git')]).

% Install non-interactively (useful in scripts)
?- pack_install(mavis, [interactive(false)]).
```

## Example: Using an Installed Pack

```prolog
% After pack_install(mavis):
:- use_module(library(mavis)).

:- begin_tests(typed).
test(typed_append) :-
    append([1,2], [3,4], Result),
    is_list(Result).
:- end_tests(typed).
```

**Notable packs**:
- `mavis` — runtime type checking
- `func` — functional idioms (composition, currying)
- `tap` — test anything protocol for testing
- `prosqlite` — SQLite bindings
- `rocksdb` — RocksDB bindings for fast key-value storage

**Tip**: Packs are installed to `~/.local/share/swi-prolog/pack/` by default. Use `pack_rebuild/1` after upgrading SWI-Prolog if packs have C/C++ components.

---

**See also**: [Modules](modules.md) (packs are loaded as modules via use_module/1).

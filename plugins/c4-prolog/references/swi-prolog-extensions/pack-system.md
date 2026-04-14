# Pack System (Third-Party Libraries)

**Problem**: Not everything is built-in. The pack system lets you install community libraries.

```prolog
% Install a pack
?- pack_install(mavis).      % Type checking
?- pack_install(func).       % Functional programming
?- pack_install(dcg_utils).  % Extra DCG utilities

% List installed packs
?- pack_list_installed.

% Search for packs
?- pack_search(csv).
```

**Notable packs**:
- `mavis` — runtime type checking
- `func` — functional idioms (composition, currying)
- `tap` — test anything protocol for testing
- `prosqlite` — SQLite bindings
- `rocksdb` — RocksDB bindings for fast key-value storage

---

**See also**: [Modules](modules.md) (packs are loaded as modules via use_module/1).

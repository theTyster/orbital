# Migration

The marketplace formerly known as `logic-focused-claude` was renamed to `orbital-shift`, and is now renamed again to **`orbital`** (matching the canonical repo URL).

In the latest rename, all four plugins have been renamed to single-word identifiers that fit the orbital metaphor:

| Old plugin name | New plugin name | README title          |
| --------------- | --------------- | --------------------- |
| `logic-focused` | `shifting`      | `orbital-shifting`    |
| `c4-prolog`     | `scaffolding`   | `orbital-scaffolding` |
| `orchestrate`   | `trajectory`    | `orbital-trajectory`  |
| `utilities`     | `telemetry`     | `orbital-telemetry`   |

Namespaced skill references in code and documentation also change: `logic-focused:close-world` becomes `shifting:close-world`, `c4-prolog:c4-analyze` becomes `scaffolding:c4-analyze`, and so on.

## If you have an existing install

```bash
claude /uninstall-plugin logic-focused
claude /uninstall-plugin c4-prolog
claude /uninstall-plugin orchestrate
claude /uninstall-plugin utilities

claude /install-plugin https://github.com/theTyster/orbital

# After install, the new plugin set is:
#   shifting, scaffolding, trajectory, telemetry
```

## If you have a local clone

Update the remote so future `git fetch` resolves to the new canonical URL:

```bash
git remote set-url origin git@github.com:theTyster/orbital.git
```

## Why the rename

The original name (`logic-focused-claude`) described one of the marketplace's plugins (the formal-reasoning pipeline) rather than the marketplace as a whole. The intermediate `orbital-shift` name introduced the orbits metaphor — skills arranged in orbits of intent around a shared core — and the latest rename to `orbital` shortens that to the canonical noun.

Each plugin's new single-word identifier corresponds to a role in that orbit: `shifting` reasons across formal/informal frames, `scaffolding` builds the architectural substrate, `trajectory` plans the pipeline's flight path, and `telemetry` reports back from the dev-tools instruments.

## Cleanup

This file can be removed in a future maintenance pass once the rename has been live long enough that the GitHub redirect is unlikely to be load-bearing for any user.

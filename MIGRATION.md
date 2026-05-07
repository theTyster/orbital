# Migration

The marketplace formerly known as `logic-focused-claude` has been renamed to **`orbital-shift`**.

The four plugins inside the marketplace (`logic-focused`, `c4-prolog`, `multi-plan`, `utilities`) keep their names in this rename — only the marketplace identity (repo URL + `marketplace.json` `name`) changes. A separate restructure-by-intent change will rename and split plugins later; that change will ship its own migration steps.

## If you have an existing install

GitHub auto-redirects from the old repo URL for a grace period, so existing installs keep working temporarily. To migrate cleanly:

```bash
claude /uninstall-plugin logic-focused
claude /uninstall-plugin c4-prolog
claude /uninstall-plugin multi-plan
claude /uninstall-plugin utilities

claude /install-plugin https://github.com/theTyster/orbital-shift
```

## If you have a local clone

Update the remote so future `git fetch` resolves to the new canonical URL:

```bash
git remote set-url origin git@github.com:theTyster/orbital-shift.git
```

## Why the rename

The original name described one of the marketplace's plugins (the `logic-focused` formal-reasoning pipeline) rather than the marketplace as a whole. The marketplace is being restructured around skill **intent** — gather, formalize, implement, review, orchestrate, utility — and `orbital-shift` carries the *orbits* metaphor that restructure uses (skills arranged in orbits of intent around a shared core). The `-claude` suffix on the old name was redundant given the marketplace.json + install command already make the Claude-Code context explicit.

## Cleanup

This file can be removed in a future maintenance pass once the rename has been live long enough that the GitHub redirect is unlikely to be load-bearing for any user.

Forked from [jennings/claude-marketplace](https://github.com/jennings/claude-marketplace).

## Adding the marketplace

```command
$ claude plugin marketplace add SalTor/claude-marketplace
```

## Installing a plugin

```command
$ claude plugin install jujutsu@saltor
```

## Plugins

- [`jujutsu`](plugins/jujutsu/README.md) — use Jujutsu (jj) instead of git, and
  back Claude Code's worktree isolation with jj workspaces.

  Needs one manual step after install: as of Claude Code 2.1.221,
  `claude --worktree <name>` does **not** honor `WorktreeCreate` /
  `WorktreeRemove` hooks that come from a plugin, because those hooks are
  resolved before plugins load. Copy them into your
  `settings.json` — see
  [Required setup](plugins/jujutsu/README.md#required-setup-copy-the-worktree-hooks-into-your-settings).

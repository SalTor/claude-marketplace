# jj-worktrees

Replaces Claude Code's default **git worktree** isolation with **Jujutsu (jj)
workspaces**. When you run `claude --worktree <name>` (or Claude uses the
`EnterWorktree` tool), the plugin's hooks run `jj workspace add` instead of
`git worktree add`, and clean up with `jj workspace forget` on session end.

## How it works

- `WorktreeCreate` → `hooks/workspace-create.sh`
  Reads `.name` and `.cwd` from the stdin JSON payload, runs
  `jj workspace add --name <name> <path>`, copies any `.worktreeinclude` files,
  and prints the workspace path to stdout (which Claude Code uses as the
  session working directory). Any non-zero exit aborts creation.
- `WorktreeRemove` → `hooks/workspace-remove.sh`
  Reads `.worktree_path`, runs `jj workspace forget <name>`, and removes the
  directory.

The bundled `jj-workspaces` skill teaches Claude to prefer jj workspaces and
never fall back to `git worktree` commands in this repo.

## Required setup: copy the worktree hooks into your settings

Claude Code resolves the `WorktreeCreate` / `WorktreeRemove` hooks *before*
plugins are loaded, so this plugin's `hooks/hooks.json` is **not honored** when
you start a session with `claude --worktree <name>` — you get git's default
worktree behavior instead of a jj workspace. (The in-session `EnterWorktree`
tool does load plugin hooks and works without this setup.)

Hooks declared in your own `settings.json` *are* honored, so after installing
the plugin, copy the two hook entries there.

This describes Claude Code 2.1.221. If a later release resolves worktree hooks
after plugins load, this step becomes unnecessary — and the copied hooks would
then run in addition to the plugin's own, so remove them from `settings.json`
at that point.

Pick a settings file first:

- `~/.claude/settings.json` — applies to every project. `workspace-create.sh`
  exits non-zero outside a jj repo, which aborts worktree creation, so only do
  this if every repo you use worktrees in is jj-backed.
- `<project>/.claude/settings.json` — applies to one project. Safer if you mix
  jj and plain-git repos.

### Option A: let Claude do it

Run `claude` and paste:

> Install the jujutsu plugin's worktree hooks into my user settings. Read
> `~/.claude/plugins/installed_plugins.json`, take the `installPath` for
> `jujutsu@jennings`, and add `WorktreeCreate` and `WorktreeRemove` entries to
> the `hooks` object in `~/.claude/settings.json` that run
> `bash "<installPath>/hooks/workspace-create.sh"` (timeout 60) and
> `bash "<installPath>/hooks/workspace-remove.sh"` (timeout 30). Write the
> install path out in full — `${CLAUDE_PLUGIN_ROOT}` is not defined for hooks
> that come from settings.json. Merge into the existing hooks; don't drop
> anything that's already there.

Swap `~/.claude/settings.json` for `<project>/.claude/settings.json` in that
prompt to scope the hooks to a single project.

### Option B: do it by hand

Find the plugin's install path:

```command
$ jq -r '.plugins["jujutsu@jennings"][0].installPath' \
    ~/.claude/plugins/installed_plugins.json
/Users/you/.claude/plugins/cache/jennings/jujutsu/0.0.1
```

Then merge these two keys into the `hooks` object in your chosen
`settings.json`, substituting that path:

```json
{
  "hooks": {
    "WorktreeCreate": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"/Users/you/.claude/plugins/cache/jennings/jujutsu/0.0.1/hooks/workspace-create.sh\"",
            "timeout": 60
          }
        ]
      }
    ],
    "WorktreeRemove": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash \"/Users/you/.claude/plugins/cache/jennings/jujutsu/0.0.1/hooks/workspace-remove.sh\"",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

The path must be absolute and spelled out: `${CLAUDE_PLUGIN_ROOT}` is only
defined for hooks that come from a plugin, and `~` is not expanded inside the
quoted command.

**Redo this after every plugin update.** The install path is version-pinned
(`.../jujutsu/0.0.1`), so a version bump leaves the hooks pointing at a
directory that no longer exists and worktree creation fails until you point
them at the new path.

## Skills

- `jujutsu` — teaches Claude to use the `jj` CLI instead of `git` for source
  control (status, log, diff, describing/committing, editing history,
  bookmarks, remotes, conflict resolution, and pull requests).

## Requirements

- `jj` (Jujutsu) on `PATH`
- `jq` on `PATH`
- The project must be a jj repo. For git projects: `jj git init --colocate`.

## Configuration

### Workspace layout

Controls where new workspaces are created:

| Layout | Location for workspace `feature` in `/path/to/repo` |
| --- | --- |
| `sibling` (default) | `/path/to/repo-feature` |
| `nested` | `/path/to/repo/feature` |

Set it per-repo (or per-user with `--user`) via jj config:

```sh
jj config set --repo claude-code.workspace-layout nested
```

Or per-invocation via the environment, which takes precedence over jj config:

```sh
JJ_WORKSPACE_LAYOUT=nested claude --worktree feature
```

Under the `nested` layout the create hook also appends the workspace directory
to `.git/info/exclude` (and the remove hook takes it back out) so colocated
repos don't report the workspace as untracked. jj itself already skips nested
workspaces when snapshotting the outer working copy, so no `.gitignore` entry
is needed for `jj status`.

### Other settings

- `JJ_WORKTREE_DIR` — absolute path to the parent directory where workspaces
  are created, named `<repo>-<name>`. Applies to the `sibling` layout only;
  ignored (with a warning) when the layout is `nested`.

## Notes

Because a configured `WorktreeCreate` hook fully replaces the default git
behavior, Claude Code no longer processes `.worktreeinclude` itself — the
create hook replicates that behavior instead.

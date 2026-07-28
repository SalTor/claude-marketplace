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

## Skills

- `jujutsu` — teaches Claude to use the `jj` CLI instead of `git` for source
  control (status, log, diff, describing/committing, editing history,
  bookmarks, remotes, conflict resolution, and pull requests).

## Requirements

- `jj` (Jujutsu) on `PATH`
- `jq` on `PATH`
- The project must be a jj repo. For git projects: `jj git init --colocate`.

## Configuration

- `JJ_WORKTREE_DIR` — absolute path to the parent directory where workspaces
  are created. Defaults to a sibling of the repo root, named `<repo>-<name>`.

## Notes

Because a configured `WorktreeCreate` hook fully replaces the default git
behavior, Claude Code no longer processes `.worktreeinclude` itself — the
create hook replicates that behavior instead.

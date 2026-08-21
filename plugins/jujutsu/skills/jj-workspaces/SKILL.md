---
name: jj-workspaces
description: >
  Use when working in a repository that uses Jujutsu (jj) and the user asks to
  create parallel/isolated working environments, work in a worktree, spin up a
  worktree, or run parallel sessions. Explains that this project uses jj
  workspaces instead of git worktrees, that workspaces belong at
  ~/code/workspaces/<repo>/<slug>, and how creation/removal is handled by the
  WorktreeCreate/WorktreeRemove hooks.
---

# jj workspaces instead of git worktrees

This project uses Jujutsu (jj). Isolation is provided by **jj workspaces**, not
git worktrees. The plugin's `WorktreeCreate` and `WorktreeRemove` hooks
transparently swap `git worktree add/remove` for `jj workspace add/forget`, so
the normal Claude Code worktree flow works unchanged.

## What to do

- When the user wants an isolated environment, use the standard worktree flow
  (`claude --worktree <name>`, or the `EnterWorktree` tool during a session).
  The hooks route it to `jj workspace add` automatically. Do NOT run
  `git worktree add` manually.
- Never suggest `git worktree` commands in this repo. If a user asks for one,
  explain that isolation here is backed by jj workspaces and the worktree flow
  already produces one.
- A jj workspace is a separate working directory sharing the same repo. Each
  workspace has its own working-copy commit (`@`). There are no branches to
  create — the workspace name is the unit of isolation.
- Workspaces belong at **`~/code/workspaces/<repo>/<slug>`**. The create hook's
  default `central` layout produces exactly that, so the standard worktree flow
  already lands in the right place — do not pass a path or pick a directory
  yourself. When creating one by hand, use
  `jj workspace add --name <slug> ~/code/workspaces/<repo>/<slug>`.
- Never put a workspace next to the repo root (`<repo>-<slug>`) or inside it
  (`<repo>/<slug>`). Those are the `sibling` and `nested` layouts, kept only for
  repos that opt into them explicitly.
- After creating a workspace, bootstrap it before running any tooling: read
  `~/code/workspaces/AGENTS.md`, install dependencies, and copy the gitignored
  config the primary checkout carries. The hook copies whatever
  `.worktreeinclude` lists, which usually covers the config but not the install.

## Key differences from git worktrees

- **No branch is created.** git worktrees put you on `worktree-<name>`; a jj
  workspace just gives you a fresh `@` commit in the shared repo.
- **Shared operation log.** All workspaces share one repo and op log, so
  `jj op log` and `jj log` see each other's commits immediately.
- **Cleanup forgets, not deletes history.** Removal runs `jj workspace forget`
  and deletes the directory; commits already made remain reachable in the repo.

## Requirements and failure modes

- The repo must already be a jj repo. For a git-backed project, that means
  `jj git init --colocate` has been run. If creation fails with "not inside a
  jj repository", tell the user to initialize jj first.
- Workspace location is controlled by the layout setting, resolved from
  `JJ_WORKSPACE_LAYOUT` first, then the jj config key
  `claude-code.workspace-layout`, defaulting to `central`:
  - `central` (default) — `<root>/<repo>/<name>`, where `<root>` comes from
    `JJ_WORKSPACE_ROOT`, then the jj config key `claude-code.workspace-root`,
    defaulting to `~/code/workspaces`. The root must be an absolute path. The
    create hook makes the per-repo directory if it is missing; the remove hook
    reaps it once its last workspace is gone.
  - `sibling` — `<repo-root>-<name>` next to the repo root. Override the parent
    directory with `JJ_WORKTREE_DIR` (absolute path).
  - `nested` — `<repo-root>/<name>` inside the default workspace. Set it with
    `jj config set --repo claude-code.workspace-layout nested`. The hooks keep
    the directory in `.git/info/exclude` so colocated repos stay clean;
    `jj status` in the outer workspace already ignores nested workspaces.
- Local gitignored files listed in `.worktreeinclude` are copied into new
  workspaces by the create hook (Claude Code skips `.worktreeinclude` on its
  own once a WorktreeCreate hook is configured, so the hook does it).

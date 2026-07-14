---
name: jj-workspaces
description: >
  Use when working in a repository that uses Jujutsu (jj) and the user asks to
  create parallel/isolated working environments, work in a worktree, spin up a
  worktree, or run parallel sessions. Explains that this project uses jj
  workspaces instead of git worktrees, and how creation/removal is handled by
  the WorktreeCreate/WorktreeRemove hooks.
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
- Default workspace location is a sibling of the repo root named
  `<repo>-<name>`. Override the parent directory by setting `JJ_WORKTREE_DIR`
  to an absolute path before launching Claude Code.
- Local gitignored files listed in `.worktreeinclude` are copied into new
  workspaces by the create hook (Claude Code skips `.worktreeinclude` on its
  own once a WorktreeCreate hook is configured, so the hook does it).

#!/usr/bin/env bash
# WorktreeRemove hook — replaces `git worktree remove` with jj workspace teardown.
#
# Contract:
#   - JSON payload on stdin includes .worktree_path (the dir created earlier).
#     Some payloads also carry .name and .cwd.
#   - Diagnostics to stderr; stdout is not used as a path here.
set -euo pipefail

INPUT="$(cat)"

WORKSPACE_PATH="$(printf '%s' "$INPUT" | jq -r '.worktree_path // empty')"
NAME="$(printf '%s' "$INPUT" | jq -r '.name // empty')"

if [ -z "$WORKSPACE_PATH" ]; then
  echo "jj-worktrees: no .worktree_path in WorktreeRemove payload" >&2
  exit 1
fi

if ! command -v jj >/dev/null 2>&1; then
  echo "jj-worktrees: 'jj' not found on PATH" >&2
  exit 1
fi

# Derive the workspace name if the payload didn't supply it: the create hook
# named the directory "<repo>-<name>", and named the workspace "<name>".
if [ -z "$NAME" ]; then
  NAME="$(basename "$WORKSPACE_PATH" | sed 's/^[^-]*-//')"
fi

# Forget the workspace from the repo's operation log. `jj workspace forget`
# must be run from a working copy that still belongs to the repo, so run it
# from the workspace path itself (still valid until we delete the dir).
if [ -d "$WORKSPACE_PATH" ]; then
  ( cd "$WORKSPACE_PATH" && jj workspace forget "$NAME" >&2 2>/dev/null ) || \
    echo "jj-worktrees: 'jj workspace forget $NAME' did not succeed (may already be gone)" >&2
  rm -rf "$WORKSPACE_PATH"
else
  # Directory already gone; try to forget by name from any nearby repo context.
  echo "jj-worktrees: workspace path missing, attempting forget by name only" >&2
  jj workspace forget "$NAME" >&2 2>/dev/null || true
fi

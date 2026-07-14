#!/usr/bin/env bash
# WorktreeCreate hook — replaces `git worktree add` with `jj workspace add`.
#
# Contract (from Claude Code hooks reference):
#   - JSON payload arrives on stdin with at least: .name, .cwd
#   - stdout MUST be ONLY the absolute path to the created working directory.
#     Anything else on stdout corrupts the path Claude Code uses, so all
#     diagnostics go to stderr.
#   - Any non-zero exit aborts worktree creation.
set -euo pipefail

INPUT="$(cat)"

NAME="$(printf '%s' "$INPUT" | jq -r '.name // empty')"
REPO_CWD="$(printf '%s' "$INPUT" | jq -r '.cwd // empty')"

if [ -z "$NAME" ]; then
  echo "jj-worktrees: no .name in WorktreeCreate payload" >&2
  exit 1
fi
if [ -z "$REPO_CWD" ]; then
  REPO_CWD="$PWD"
fi

if ! command -v jj >/dev/null 2>&1; then
  echo "jj-worktrees: 'jj' not found on PATH" >&2
  exit 1
fi

cd "$REPO_CWD"

# Confirm we're inside a jj repo (colocated or native). `jj root` exits
# non-zero outside a repo.
if ! REPO_ROOT="$(jj root 2>/dev/null)"; then
  echo "jj-worktrees: $REPO_CWD is not inside a jj repository. Run 'jj git init --colocate' first." >&2
  exit 1
fi

# Place workspaces as siblings of the repo root by default, matching jj's own
# convention that workspace paths live outside the primary working copy.
# Override with JJ_WORKTREE_DIR (absolute path to a parent directory).
PARENT_DIR="${JJ_WORKTREE_DIR:-$(dirname "$REPO_ROOT")}"
WORKSPACE_PATH="$PARENT_DIR/$(basename "$REPO_ROOT")-$NAME"

if [ -e "$WORKSPACE_PATH" ]; then
  echo "jj-worktrees: target path already exists: $WORKSPACE_PATH" >&2
  exit 1
fi

# `jj workspace add` creates a new working copy sharing the repo, with its own
# working-copy commit. Name the workspace after $NAME so `jj workspace list`
# and `jj workspace forget` can target it during removal.
if ! jj workspace add --name "$NAME" "$WORKSPACE_PATH" >&2; then
  echo "jj-worktrees: 'jj workspace add' failed" >&2
  exit 1
fi

# Copy local gitignored config into the new workspace. Since a configured
# WorktreeCreate hook bypasses .worktreeinclude, replicate it here if present.
INCLUDE_FILE="$REPO_ROOT/.worktreeinclude"
if [ -f "$INCLUDE_FILE" ]; then
  while IFS= read -r pattern || [ -n "$pattern" ]; do
    case "$pattern" in
      ''|'#'*) continue ;;
    esac
    for src in $REPO_ROOT/$pattern; do
      [ -e "$src" ] || continue
      rel="${src#$REPO_ROOT/}"
      dest="$WORKSPACE_PATH/$rel"
      mkdir -p "$(dirname "$dest")"
      cp -R "$src" "$dest" 2>/dev/null || true
    done
  done < "$INCLUDE_FILE"
fi

# ONLY the path goes to stdout.
printf '%s\n' "$WORKSPACE_PATH"

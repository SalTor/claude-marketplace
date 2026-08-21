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
case "$NAME" in
  */*|.|..)
    echo "jj-worktrees: workspace name must be a single path component: $NAME" >&2
    exit 1
    ;;
esac
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

# Where to put the new workspace. Three layouts:
#   central (default) — "<root>/<repo>/<name>" under a shared workspace root
#   sibling           — next to the repo root, named "<repo>-<name>"
#   nested            — inside the repo root, named "<name>"
# Resolution order: JJ_WORKSPACE_LAYOUT env var, then the jj config key
# `claude-code.workspace-layout` (set it per-repo with
# `jj config set --repo claude-code.workspace-layout nested`), then "central".
LAYOUT="${JJ_WORKSPACE_LAYOUT:-}"
if [ -z "$LAYOUT" ]; then
  LAYOUT="$(jj config get claude-code.workspace-layout 2>/dev/null || true)"
fi
LAYOUT="${LAYOUT:-central}"

case "$LAYOUT" in
  central)
    if [ -n "${JJ_WORKTREE_DIR:-}" ]; then
      echo "jj-worktrees: ignoring JJ_WORKTREE_DIR because layout is 'central' (use JJ_WORKSPACE_ROOT)" >&2
    fi
    ROOT_DIR="${JJ_WORKSPACE_ROOT:-}"
    if [ -z "$ROOT_DIR" ]; then
      ROOT_DIR="$(jj config get claude-code.workspace-root 2>/dev/null || true)"
    fi
    ROOT_DIR="${ROOT_DIR:-$HOME/code/workspaces}"
    case "$ROOT_DIR" in
      /*) ;;
      *)
        echo "jj-worktrees: workspace root must be an absolute path: $ROOT_DIR" >&2
        exit 1
        ;;
    esac
    WORKSPACE_PATH="$ROOT_DIR/$(basename "$REPO_ROOT")/$NAME"
    ;;
  sibling)
    # jj's own convention: workspace paths live outside the primary working
    # copy. Override the parent directory with JJ_WORKTREE_DIR.
    PARENT_DIR="${JJ_WORKTREE_DIR:-$(dirname "$REPO_ROOT")}"
    WORKSPACE_PATH="$PARENT_DIR/$(basename "$REPO_ROOT")-$NAME"
    ;;
  nested)
    if [ -n "${JJ_WORKTREE_DIR:-}" ]; then
      echo "jj-worktrees: ignoring JJ_WORKTREE_DIR because layout is 'nested'" >&2
    fi
    WORKSPACE_PATH="$REPO_ROOT/$NAME"
    ;;
  *)
    echo "jj-worktrees: invalid workspace layout '$LAYOUT' (expected 'central', 'sibling' or 'nested')" >&2
    exit 1
    ;;
esac

if [ -e "$WORKSPACE_PATH" ]; then
  echo "jj-worktrees: target path already exists: $WORKSPACE_PATH" >&2
  exit 1
fi

# The central layout adds a per-repo directory level that may not exist yet.
mkdir -p "$(dirname "$WORKSPACE_PATH")"

# `jj workspace add` creates a new working copy sharing the repo, with its own
# working-copy commit. Name the workspace after $NAME so `jj workspace list`
# and `jj workspace forget` can target it during removal.
if ! jj workspace add --name "$NAME" "$WORKSPACE_PATH" >&2; then
  echo "jj-worktrees: 'jj workspace add' failed" >&2
  exit 1
fi

# jj skips nested workspaces when snapshotting the outer working copy, but a
# colocated git repo does not — the workspace would show up as an untracked
# directory in `git status`. Exclude it locally (never committed).
if [ "$LAYOUT" = "nested" ]; then
  GIT_DIR_PATH="$(git -C "$REPO_ROOT" rev-parse --git-common-dir 2>/dev/null || true)"
  case "$GIT_DIR_PATH" in
    '') ;;
    /*) ;;
    *) GIT_DIR_PATH="$REPO_ROOT/$GIT_DIR_PATH" ;;
  esac
  if [ -n "$GIT_DIR_PATH" ] && [ -d "$GIT_DIR_PATH" ]; then
    EXCLUDE_FILE="$GIT_DIR_PATH/info/exclude"
    if ! grep -qxF "/$NAME/" "$EXCLUDE_FILE" 2>/dev/null; then
      mkdir -p "$GIT_DIR_PATH/info"
      printf '/%s/\n' "$NAME" >> "$EXCLUDE_FILE"
    fi
  fi
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
      # Under the nested layout the new workspace is itself inside $REPO_ROOT,
      # so a broad pattern could match it. Never copy a workspace into itself.
      case "$src" in
        "$WORKSPACE_PATH"|"$WORKSPACE_PATH"/*) continue ;;
      esac
      rel="${src#$REPO_ROOT/}"
      dest="$WORKSPACE_PATH/$rel"
      mkdir -p "$(dirname "$dest")"
      cp -R "$src" "$dest" 2>/dev/null || true
    done
  done < "$INCLUDE_FILE"
fi

# ONLY the path goes to stdout.
printf '%s\n' "$WORKSPACE_PATH"

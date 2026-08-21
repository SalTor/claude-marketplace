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

resolve_path() {
  ( cd "$1" 2>/dev/null && pwd -P ) || printf '%s' "$1"
}

# A nested-layout workspace sits directly inside another jj working copy.
PARENT_PATH="$(dirname "$WORKSPACE_PATH")"
NESTED=0
if [ -d "$PARENT_PATH/.jj" ]; then
  NESTED=1
fi

# Derive the workspace name if the payload didn't supply it. Preferred method is
# asking the repo which workspace lives at this path, which works for both the
# sibling and nested layouts.
if [ -z "$NAME" ] && [ -d "$WORKSPACE_PATH" ]; then
  TARGET_REAL="$(resolve_path "$WORKSPACE_PATH")"
  WS_LIST="$( ( cd "$WORKSPACE_PATH" && jj workspace list -T 'name ++ "\t" ++ root ++ "\n"' ) 2>/dev/null || true )"
  while IFS="$(printf '\t')" read -r ws_name ws_root; do
    [ -n "$ws_name" ] && [ -n "${ws_root:-}" ] || continue
    if [ "$(resolve_path "$ws_root")" = "$TARGET_REAL" ]; then
      NAME="$ws_name"
      break
    fi
  done <<EOF
$WS_LIST
EOF
fi

# A central-layout workspace sits at "<root>/<repo>/<name>", so its grandparent
# is the configured workspace root and the directory name is the workspace name.
CENTRAL=0
CENTRAL_ROOT="${JJ_WORKSPACE_ROOT:-}"
if [ -z "$CENTRAL_ROOT" ]; then
  CENTRAL_ROOT="$( ( cd "$PARENT_PATH" 2>/dev/null && jj config get claude-code.workspace-root ) 2>/dev/null || true )"
fi
CENTRAL_ROOT="${CENTRAL_ROOT:-$HOME/code/workspaces}"
if [ "$NESTED" -eq 0 ] && [ "$(dirname "$PARENT_PATH")" = "${CENTRAL_ROOT%/}" ]; then
  CENTRAL=1
fi

# Last resort: infer from the directory name. The create hook names the
# directory "<name>" under the central and nested layouts, "<repo>-<name>"
# under sibling.
if [ -z "$NAME" ]; then
  if [ "$NESTED" -eq 1 ] || [ "$CENTRAL" -eq 1 ]; then
    NAME="$(basename "$WORKSPACE_PATH")"
  else
    NAME="$(basename "$WORKSPACE_PATH" | sed 's/^[^-]*-//')"
  fi
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

# Reap the per-repo directory the central layout created, but only once its last
# workspace is gone. rmdir refuses a non-empty directory, which is what we want.
if [ "$CENTRAL" -eq 1 ]; then
  rmdir "$PARENT_PATH" 2>/dev/null || true
fi

# Drop the local git exclude entry the create hook added for nested workspaces.
if [ "$NESTED" -eq 1 ]; then
  GIT_DIR_PATH="$(git -C "$PARENT_PATH" rev-parse --git-common-dir 2>/dev/null || true)"
  case "$GIT_DIR_PATH" in
    '') ;;
    /*) ;;
    *) GIT_DIR_PATH="$PARENT_PATH/$GIT_DIR_PATH" ;;
  esac
  EXCLUDE_FILE="${GIT_DIR_PATH:-}/info/exclude"
  DIR_NAME="$(basename "$WORKSPACE_PATH")"
  if [ -n "$GIT_DIR_PATH" ] && [ -f "$EXCLUDE_FILE" ] && grep -qxF "/$DIR_NAME/" "$EXCLUDE_FILE"; then
    TMP_EXCLUDE="$EXCLUDE_FILE.jj-worktrees.$$"
    # grep exits 1 when every line was filtered out — that is success here.
    set +e
    grep -vxF "/$DIR_NAME/" "$EXCLUDE_FILE" > "$TMP_EXCLUDE"
    GREP_RC=$?
    set -e
    if [ "$GREP_RC" -le 1 ]; then
      mv "$TMP_EXCLUDE" "$EXCLUDE_FILE"
    else
      rm -f "$TMP_EXCLUDE"
    fi
  fi
fi

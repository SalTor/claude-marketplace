---
name: jujutsu
description: >
  Use Jujutsu (jj) version control instead of git when working in a Jujutsu
  repository (a directory containing a .jj folder). Covers the jj CLI: status,
  log, diff, describing/committing changes, editing history, bookmarks, remotes,
  conflict resolution, and creating pull requests. Prefer jj commands over git.
match:
  - directory_exists: .jj
---

# Jujutsu (jj) Version Control

This repository uses Jujutsu (jj), a modern version control system. **Use `jj`
commands instead of `git` commands.** Never run raw `git` commands in a jj
repository unless explicitly asked.

## Core Concepts

- **The working copy IS a commit.** There is no staging area / index. Every
  change you make to files is automatically part of the working-copy commit (`@`).
- **Change IDs vs Commit IDs.** Each change has a stable *change ID* that
  persists across rebases/amends. Commit IDs (SHA hashes) change when content
  changes. Prefer change IDs when referring to revisions.
- **No current branch.** You are always in "detached HEAD" mode. Bookmarks
  (jj's name for branches) are optional labels you move manually.
- **Automatic rebasing.** When you rewrite a commit, all descendants are
  automatically rebased on top. Bookmarks and the working copy update
  automatically.
- **Conflicts are committable.** Merge conflicts are recorded in commits
  without failing. You can resolve them later with `jj resolve` or by editing
  the files and letting the working copy auto-snapshot.
- **Operation log.** Every repository mutation is recorded. Use `jj undo` or
  `jj op restore` to recover from mistakes.
- **Immutable commits.** Commits on `main`/`trunk` and their ancestors are
  typically immutable. Don't try to rewrite them.
- **Virtual root commit.** All commits descend from a single root (all-zero
  hash). There is no "unborn branch" state.

## Revsets

Jujutsu uses a revset language to select commits:

| Symbol | Meaning |
|--------|---------|
| `@` | Working-copy commit |
| `@-` | Parent of working copy |
| `@--` | Grandparent of working copy |
| `X-` | Parent of X |
| `X..Y` | DAG range from X to Y (exclusive of X) |
| `::X` | Ancestors of X (inclusive) |
| `X::` | Descendants of X (inclusive) |
| `X \| Y` | Union |
| `X & Y` | Intersection |
| `trunk()` | The trunk/main bookmark |
| `mine()` | Commits authored by you |
| `bookmarks()` | All bookmarked commits |
| `all()` | All visible commits |
| `empty()` | Empty changes |
| `description(text)` | Commits whose description contains text |
| `diff_contains(text)` | Commits whose diff contains text |

## Command Reference — Git to jj

### Repository Setup

| Task | Command |
|------|---------|
| Init new repo | `jj git init` |
| Clone | `jj git clone <url> <dest>` |

### Daily Workflow

| Task | Command |
|------|---------|
| Status | `jj status` |
| Log (default: your work) | `jj log` |
| Log (all commits) | `jj log -r 'all()'` |
| Log (ancestors of @) | `jj log -r ::@` |
| Diff (working copy) | `jj diff` |
| Diff (specific revision) | `jj diff -r <rev>` |
| Diff (between two revs) | `jj diff --from A --to B` |
| Diff (summary/stat) | `jj diff --stat` or `jj diff -s` |
| Show a revision | `jj show <rev>` |
| Blame/annotate | `jj file annotate <path>` |

### Creating and Describing Commits

| Task | Command |
|------|---------|
| Describe working copy | `jj describe -m "message"` |
| Finalize commit & start new | `jj commit -m "message"` |
| Edit description of any commit | `jj describe <rev> -m "message"` |
| Create new empty change | `jj new` |
| Create change on top of X | `jj new X` |
| Create merge commit | `jj new A B` |

### Editing History

| Task | Command |
|------|---------|
| Amend into parent | `jj squash` (moves working copy changes into parent) |
| Squash and adopt parent message | `jj squash --use-destination-message` |
| Squash and set new message | `jj squash --message "msg"` |
| Squash into specific commit | `jj squash --into <rev>` |
| Interactive squash | `jj squash -i` |
| Split a commit | `jj split` (interactive) or `jj split -r <rev>` |
| Edit a historical commit | `jj edit <rev>` (sets it as working copy) |
| Edit commit contents | `jj diffedit -r <rev>` |
| Abandon/discard a commit | `jj abandon <rev>` |
| Restore working copy | `jj restore` (resets to parent, like `git checkout -- .`) |
| Restore specific paths | `jj restore <paths>...` |
| Restore from a revision | `jj restore --from <rev> <paths>...` |
| Rebase onto new parent | `jj rebase -s <rev> -d <destination>` |
| Rebase branch | `jj rebase -b <rev> -d <destination>` |
| Rebase single commit | `jj rebase -r <rev> -d <destination>` |
| Cherry-pick / duplicate | `jj duplicate <rev>` |
| Revert a commit | `jj revert -r <rev>` |
| Move to child commit | `jj next` |
| Move to parent commit | `jj prev` |
| Absorb changes into stack | `jj absorb` |
| Rearrange commits interactively | `jj arrange` |
| Undo last operation | `jj undo` |

### Bookmarks (Branches)

| Task | Command |
|------|---------|
| List bookmarks | `jj bookmark list` |
| Create bookmark | `jj bookmark create <name> -r <rev>` |
| Move bookmark | `jj bookmark move <name> --to <rev>` |
| Delete bookmark | `jj bookmark delete <name>` |
| Rename bookmark | `jj bookmark rename <old> <new>` |

### Tags

| Task | Command |
|------|---------|
| List tags | `jj tag list` |
| Create/set tag | `jj tag set <name> -r <rev>` |
| Delete tag | `jj tag delete <name>` |

### Remote Operations

| Task | Command |
|------|---------|
| Fetch | `jj git fetch` |
| Push all bookmarks | `jj git push --all` |
| Push specific bookmark | `jj git push --bookmark <name>` |
| Push current change | `jj git push -r @` (pushes bookmark pointing at @) |
| Add remote | `jj git remote add <name> <url>` |
| List remotes | `jj git remote list` |

### File Operations

| Task | Command |
|------|---------|
| List tracked files | `jj file list` |
| Untrack file | `jj file untrack <path>` (must be in .gitignore first) |
| Search files by pattern | `jj file search <glob>` |
| Show file at revision | `jj file show <path> -r <rev>` |

### Conflict Resolution

| Task | Command |
|------|---------|
| Resolve conflicts (merge tool) | `jj resolve <path>` |
| Resolve by editing | Edit the file directly, conflicts are marked inline |

### Operations / Recovery

| Task | Command |
|------|---------|
| View operation log | `jj op log` |
| Undo last operation | `jj undo` |
| Restore to operation | `jj op restore <op-id>` |

### Workspace

| Task | Command |
|------|---------|
| Show repo root | `jj root` |

## Common Workflows

### Start new work

```sh
jj new main          # create a new change on top of main
# ... make changes ...
jj describe -m "Add feature X"
jj bookmark create feature-x    # optional: label it
jj git push --bookmark feature-x
```

### Stack of changes

```sh
jj new main
# ... work on first change ...
jj describe -m "Step 1"
jj new                # start next change on top
# ... work on second change ...
jj describe -m "Step 2"
jj new
# ... and so on ...
```

### Amend the current change

Just edit files. The working copy commit updates automatically. To update the
description: `jj describe -m "new message"`.

### Amend a parent or earlier commit

```sh
jj new <rev>          # create empty commit on top of the one to amend
# ... make changes ...
jj squash --use-destination-message   # squash into parent, keeping its message
```

Prefer this over `jj edit <rev>`. Only use `jj edit` if you have a specific
reason to work directly on a historical commit.

### Stash equivalent

```sh
jj new @-             # create a new change as sibling, old work preserved
# ... do other work ...
jj edit <change-id>   # go back to the stashed change
```

### Resolve merge conflicts

```sh
jj new main feature   # create merge
# if conflicts exist, they are recorded in the commit
jj resolve            # launch merge tool
# or edit files directly — jj auto-snapshots
```

### Create a pull request

```sh
jj git fetch
jj new main
# ... make changes ...
jj describe -m "My PR description"
jj bookmark create my-branch
jj git push --bookmark my-branch
# then use gh pr create as normal
```

## Squash Workflow (required for Claude)

Always use the squash workflow. Never use `jj edit <ID>` to modify a historical
commit directly.

### Doing work

Work in the current working-copy commit (`@`). Files are auto-tracked; no
staging needed.

### Finishing a commit

```sh
jj commit -m "message"   # describe + create new empty working copy
```

Leave the working copy on a new empty commit when done.

### Amending an earlier commit

```sh
jj new <rev>                          # empty working copy on top of target
# ... make changes ...
jj squash --use-destination-message   # fold into target, keep its message
# or, to also update the message:
jj squash --message "updated message"
```

Use `jj squash --into <rev>` if you need to target a non-parent commit.

**Do NOT use `git add`, `git commit`, or any git commands.**

## Creating Pull Requests (for Claude)

1. `jj git fetch` to get latest remote state.
2. `jj log` to understand the change stack.
3. Ensure the change(s) to push have a bookmark: `jj bookmark create <name> -r <rev>`.
4. `jj git push --bookmark <name>`.
5. Use `gh pr create` as normal for the GitHub side.

## Splitting changes

To split a commit in two with a parent/child relation, duplicate the commit to
split, discard anything that belongs in the second commit, then restore with
`--restore-descendants`:

1. Run `jj new -A COMMIT_TO_SPLIT --no-edit --message MESSAGE` to create an empty second commit
2. Run `jj new COMMIT_TO_SPLIT` to create a working copy on top of the first commit
3. Remove anything that doesn't belong in the first commit
4. Run `jj restore --to COMMIT_TO_SPLIT --restore-descendants` to update the
   first commit, leaving the remaining changes in the second.

## Important Behavioral Notes

- **No need to `git add`.** Editing/creating/deleting files is automatically
  tracked.
- **`jj commit` = describe + new.** It finalizes the current change and starts
  a fresh one. You can also just use `jj describe` + `jj new` separately.
- **`jj squash` without args** moves all changes from `@` into `@-` (like
  `git commit --amend`).
- **Prefer `jj new <rev>` + `jj squash`** over `jj edit <rev>`. Editing a
  historical commit directly makes it easy to accidentally leave the working
  copy in a non-empty state mid-stack.
- **Empty commits are normal.** The working copy often starts as an empty
  change. This is expected.
- **Use `jj undo`** if something goes wrong. It reverts the last jj operation.
- **Bookmarks don't auto-advance.** After `jj new`, bookmarks stay on the old
  commit. Move them with `jj bookmark move`.

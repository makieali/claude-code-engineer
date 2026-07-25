#!/usr/bin/env bash
# Collect the git state a handoff needs. Read-only.
set -uo pipefail

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "NOT_A_GIT_REPO"
  echo "Record what changed by hand — there is no history to reconstruct from."
  exit 0
fi

echo "=== BRANCH ==="
git rev-parse --abbrev-ref HEAD

echo "=== UPSTREAM ==="
git rev-parse --abbrev-ref '@{upstream}' 2>/dev/null || echo "(none — branch not pushed)"

echo "=== STATUS ==="
git status --short

echo "=== UNSTAGED ==="
git diff --stat

echo "=== STAGED ==="
git diff --cached --stat

echo "=== COMMITS THIS BRANCH ==="
# Commits not on the default branch — i.e. the work of this session's branch.
BASE=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||')
BASE=${BASE:-main}
CUR=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
AHEAD=""
if [ "$CUR" != "$BASE" ] && git rev-parse --verify --quiet "$BASE" >/dev/null; then
  AHEAD=$(git log --oneline "$BASE"..HEAD 2>/dev/null | head -20)
fi
if [ -n "$AHEAD" ]; then
  printf '%s\n' "$AHEAD"
else
  # On the base branch itself, or nothing ahead of it, `BASE..HEAD` is empty — which
  # would silently give a handoff no history at all. Fall back to recent commits.
  echo "(on '$CUR', nothing ahead of '$BASE' — showing recent history instead)"
  git log --oneline -10
fi

echo "=== FILES TOUCHED ==="
# Union of staged, unstaged, and untracked — what the handoff frontmatter lists.
{ git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard; } \
  | sort -u

echo "=== STASHES ==="
git stash list 2>/dev/null | head -5 || true

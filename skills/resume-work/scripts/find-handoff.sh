#!/usr/bin/env bash
# Locate the most recent handoff. Prints path, age, and the branch it was written on.
set -uo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DIR="$ROOT/plans/handoffs"
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)

if [ ! -d "$DIR" ]; then
  echo "NO_HANDOFFS"
  echo "No plans/handoffs/ directory. Reconstruct from git log and say so."
  exit 0
fi

# Filenames are YYYYMMDD-HHMMSS-slug.md, so lexical sort IS chronological order.
# That beats mtime, which copies, checkouts and rsync all destroy.
mapfile -t ALL < <(find "$DIR" -maxdepth 1 -name '*.md' -type f 2>/dev/null | sort -r)

if [ ${#ALL[@]} -eq 0 ]; then
  echo "NO_HANDOFFS"
  exit 0
fi

if [ "${1:-}" = "--all" ]; then
  echo "=== ALL HANDOFFS (newest first) ==="
  for f in "${ALL[@]}"; do
    b=$(grep -m1 '^branch:' "$f" 2>/dev/null | sed 's/^branch:[[:space:]]*//')
    s=$(grep -m1 '^status:' "$f" 2>/dev/null | sed 's/^status:[[:space:]]*//')
    printf '%s\t[%s]\t%s\n' "$(basename "$f")" "${b:-?}" "${s:-?}"
  done
  exit 0
fi

# Prefer the newest handoff written on this branch; fall back to the newest overall
# so a branch with no handoff of its own still gets context instead of nothing.
PICK=""
for f in "${ALL[@]}"; do
  b=$(grep -m1 '^branch:' "$f" 2>/dev/null | sed 's/^branch:[[:space:]]*//')
  if [ "$b" = "$BRANCH" ]; then PICK="$f"; break; fi
done

if [ -z "$PICK" ]; then
  PICK="${ALL[0]}"
  echo "NOTE: no handoff for branch '$BRANCH' — falling back to the newest overall."
fi

echo "FILE=$PICK"
echo "BRANCH_NOW=$BRANCH"
# Strip the space after the YAML colon — otherwise every value carries a leading
# space and anything parsing these lines gets " main" instead of "main".
fm() { grep -m1 "^$1:" "$PICK" 2>/dev/null | sed "s/^$1:[[:space:]]*/$2=/"; }
fm branch BRANCH_THEN
fm date   WRITTEN
fm status STATUS

# Commits landed since the handoff — the single best signal that it has gone stale.
WHEN=$(grep -m1 '^date:' "$PICK" | sed 's/^date:[[:space:]]*//')
if [ -n "$WHEN" ]; then
  N=$(git log --oneline --since="$WHEN" 2>/dev/null | wc -l | tr -d ' ')
  echo "COMMITS_SINCE=$N"
fi
echo "TOTAL_HANDOFFS=${#ALL[@]}"

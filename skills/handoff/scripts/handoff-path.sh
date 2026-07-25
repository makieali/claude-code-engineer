#!/usr/bin/env bash
# Print a safe, collision-free path for a new handoff file.
#
# The title comes from user input, so it is sanitised HERE in bash rather than
# interpolated into a command by the model. Allowlist only: a-z 0-9 . -
# Nothing else survives, so shell metacharacters cannot reach a later command.
set -uo pipefail

RAW="${1:-}"
[ -z "$RAW" ] && RAW="untitled"

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DIR="$ROOT/plans/handoffs"
mkdir -p "$DIR"

SLUG=$(printf '%s' "$RAW" \
  | tr '[:upper:]' '[:lower:]' \
  | tr -s ' \t_' '-' \
  | tr -cd 'a-z0-9.-' \
  | sed 's/^-*//; s/-*$//' \
  | cut -c1-60)
[ -z "$SLUG" ] && SLUG="untitled"

STAMP=$(date +%Y%m%d-%H%M%S)
FILE="$DIR/$STAMP-$SLUG.md"

# Append-only: a same-second save with the same title gets a suffix rather than
# clobbering the earlier file. Handoffs are a record; nothing overwrites.
if [ -e "$FILE" ]; then
  SUFFIX=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c 4)
  FILE="$DIR/$STAMP-$SLUG-${SUFFIX:-$$}.md"
fi

echo "$FILE"

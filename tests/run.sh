#!/usr/bin/env bash
# Regression suite. Every case here guards a defect that was found by running the skills
# against real code — not one was found by reading them. If a case fails, that bug is back.
#
#   tests/run.sh            all cases
#   tests/run.sh handoff    only cases whose name matches
set -uo pipefail
cd "$(dirname "$0")"
. ./lib.sh

FILTER="${1:-}"
echo "claude-code-engineer — regression suite"
echo

for c in cases/*.sh; do
  name=$(basename "$c" .sh)
  if [ -n "$FILTER" ]; then case "$name" in *"$FILTER"*) ;; *) continue;; esac; fi
  printf '\033[1m%s\033[0m\n' "$name"
  HERE=$PWD
  # Sourced in-process so PASS/FAIL accumulate; each case must return, not exit.
  . "./$c"
  cd "$HERE"
  echo
done

summary

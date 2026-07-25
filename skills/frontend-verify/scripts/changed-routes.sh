#!/usr/bin/env bash
# Report which frontend files changed on this branch, and where this project keeps its
# routing. Then stop.
#
# It deliberately does NOT map files to URLs. That mapping is framework-specific and every
# hardcoded ruleset is wrong for the framework nobody listed — and silently wrong, because
# a bad pattern yields an empty list that reads like "nothing changed". You can read the
# router config below and map it correctly for whatever this project actually uses.
set -uo pipefail

BASE="${1:-}"
if [ -z "$BASE" ]; then
  BASE=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|origin/||')
  BASE=${BASE:-main}
fi
git rev-parse --verify --quiet "$BASE" >/dev/null || { echo "NO_BASE_BRANCH ($BASE)"; exit 1; }

CHANGED=$( { git diff --name-only "$BASE"...HEAD; git diff --name-only; git diff --cached --name-only; } \
           | sort -u | grep -v '^$' )
[ -z "$CHANGED" ] && { echo "NO_CHANGES vs $BASE"; exit 0; }

echo "=== CHANGED FILES (vs $BASE) ==="
printf '%s\n' "$CHANGED" | sed 's/^/  /'

echo
echo "=== ROUTING CONFIG IN THIS PROJECT (read it to map the files above) ==="
# Look for where routes are declared, without assuming which framework declares them.
git ls-files 2>/dev/null \
  | grep -iE '(^|/)(routes?|router|pages|app)(/|\.)|\b(routes?|router)\.[a-z]+$|next\.config|nuxt\.config|svelte\.config|astro\.config|vue\.config|angular\.json|remix\.config' \
  | head -25 | sed 's/^/  /'
[ -z "$(git ls-files | grep -icE 'route|router|pages')" ] && echo "  (no obvious routing files — this may not be a routed app)"

echo
echo "=== WHICH CHANGED FILES SIT UNDER A ROUTING DIRECTORY ==="
printf '%s\n' "$CHANGED" | grep -iE '(^|/)(routes?|pages|app)/' | sed 's/^/  /' \
  || echo "  (none — the change may be components only)"

echo
echo "=== SHARED CODE CHANGED (blast radius wider than any route list) ==="
printf '%s\n' "$CHANGED" | grep -iE '(components?|ui|shared|lib|hooks|utils|design-system|styles)/' \
  | sed 's/^/  /' || echo "  (none)"

cat <<'EOF'

Now decide, do not guess:
  - read the routing config above and map the changed files to real URLs
  - if shared code changed, route mapping cannot see its reach — a button edit touches
    every page that renders it. Pick the 2-3 highest-traffic routes that use it and say
    that is what you covered
  - confirm the list with the user before capturing. A clean report on routes nobody
    touched is worse than no report
EOF

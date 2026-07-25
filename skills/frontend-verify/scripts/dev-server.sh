#!/usr/bin/env bash
# Report what is listening on the usual dev ports, and what this project says starts it.
#
# This script REPORTS OBSERVATIONS. It does not decide whether your app is running —
# that is a judgment, and an earlier version got it wrong: macOS ControlCenter listens
# on :5000 and :7000 by default, so "something answered" was read as "the dev server is
# up" in a directory with no app at all. Teaching the script to sniff harder is a
# treadmill. Read the evidence below and decide yourself.
set -uo pipefail

# Ask the OS what is actually listening rather than probing a guess-list of ports.
# A fixed list misses whatever the project chose, and wastes probes on ports nothing
# has ever bound. Fall back to the common suspects only if we cannot enumerate.
PORTS="${PORTS:-}"
if [ -z "$PORTS" ]; then
  PORTS=$(lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | awk 'NR>1{split($9,a,":"); print a[length(a)]}' \
          | grep -E '^[0-9]+$' | sort -un | tr '\n' ' ')
fi
[ -z "$PORTS" ] && PORTS="3000 4200 4321 5173 8000 8080"

echo "=== PORTS CURRENTLY LISTENING (from the OS, not a guess-list) ==="
FOUND=0
for p in $PORTS; do
  code=$(curl -s -o /dev/null -m 2 -w '%{http_code}' "http://localhost:$p" 2>/dev/null) || continue
  [ "$code" = "000" ] && continue
  FOUND=1
  title=$(curl -s -m 2 "http://localhost:$p" 2>/dev/null | grep -oiE '<title>[^<]*' | head -1 | sed 's/<title>//i')
  server=$(curl -s -m 2 -o /dev/null -D - "http://localhost:$p" 2>/dev/null | grep -i '^server:' | head -1 | tr -d '\r')
  printf '  :%-5s HTTP %s  title=%-28s %s\n' "$p" "$code" "${title:-—}" "${server:-}"
done
[ "$FOUND" = 0 ] && echo "  (nothing answering on any of: $PORTS)"

cat <<'EOF'

  Judge these yourself. A port answering is not your app — on macOS, ControlCenter
  (AirPlay Receiver) holds :5000 and :7000 and returns 403 with no HTML. Match the
  title against the project you are in before capturing anything.

EOF

echo "=== WHAT THIS PROJECT SAYS STARTS IT ==="
if [ -f package.json ]; then
  if command -v jq >/dev/null 2>&1; then
    jq -r '.scripts // {} | to_entries[] | "  npm run \(.key)   # \(.value)"' package.json
  else
    grep -E '"[a-z:-]+"\s*:' package.json | sed 's/^/  /'
  fi
fi
for f in Makefile Taskfile.yml justfile Procfile; do
  [ -f "$f" ] && { echo "  --- $f ---"; grep -iE '^[a-z_-]+:' "$f" | head -8 | sed 's/^/  /'; }
done
[ -f manage.py ]          && echo "  python manage.py runserver"
[ -f docker-compose.yml ] && echo "  docker compose up"
[ -f compose.yaml ]       && echo "  docker compose up"
[ -f Gemfile ]            && echo "  bin/rails server"
[ -f mix.exs ]            && echo "  mix phx.server"
[ -f Cargo.toml ]         && echo "  cargo run"
[ -f go.mod ]             && echo "  go run ."

cat <<'EOF'

  If your app is not up: start it in the background, wait for the port to answer with
  the title you expect, then capture. Do not capture a booting server — you will
  screenshot a loading state and report it as a bug.
EOF

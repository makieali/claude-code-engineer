#!/usr/bin/env bash
# Capture screenshots, an accessibility snapshot, and console output for one or more URLs.
# Everything lands on disk under .playwright-cli/ — the agent reads only what it needs.
#
#   capture.sh <url> [url ...]
#
# Verified against @playwright/cli 0.1.17. The CLI is young and its flags move; if a
# command is rejected, run `playwright-cli <command> --help` and fix here rather than
# switching to the MCP.
set -uo pipefail

VIEWPORTS="${VIEWPORTS:-375x812 768x1024 1440x900}"
OUT=".playwright-cli"

PW=""
for c in playwright-cli pwc; do command -v "$c" >/dev/null 2>&1 && { PW="$c"; break; }; done
if [ -z "$PW" ]; then
  npx --no-install @playwright/cli --version >/dev/null 2>&1 && PW="npx --no-install @playwright/cli"
fi
[ -z "$PW" ] && { echo "PLAYWRIGHT_CLI_MISSING"; echo "Install: npm install -g @playwright/cli"; exit 1; }

[ $# -eq 0 ] && { echo "usage: capture.sh <url> [url ...]"; exit 2; }

mkdir -p "$OUT"
if [ -d .git ] && ! grep -qxF '.playwright-cli/' .gitignore 2>/dev/null; then
  echo '.playwright-cli/' >> .gitignore
  echo "note: added .playwright-cli/ to .gitignore"
fi

# The browser must be opened before any goto/screenshot/snapshot. `goto` on its own
# fails with "The browser 'default' is not open" — a bare goto is not self-starting.
echo "=== opening browser ==="
$PW open >/dev/null 2>&1 || { echo "OPEN_FAILED — run '$PW open' by hand to see why"; exit 1; }
cleanup() { $PW close >/dev/null 2>&1 || true; }
trap cleanup EXIT

for URL in "$@"; do
  SLUG=$(printf '%s' "$URL" | sed 's|https\?://||; s|[^a-zA-Z0-9]|-|g; s|-\{2,\}|-|g; s|^-||; s|-$||' | cut -c1-50)
  [ -z "$SLUG" ] && SLUG="page"
  echo "=== $URL ==="

  if ! $PW goto "$URL" >/dev/null 2>&1; then
    echo "  NAV_FAILED — the browser is open, so this is the URL or the server."
    echo "               check: curl -sI $URL"
    continue
  fi

  for VP in $VIEWPORTS; do
    W="${VP%x*}"; H="${VP#*x}"
    $PW resize "$W" "$H" >/dev/null 2>&1 || echo "  resize $VP failed"
    # Let layout and transitions settle. `eval` is the command name — not `run-code`.
    $PW eval "() => new Promise(r => setTimeout(r, 400))" >/dev/null 2>&1 || true

    # --filename MUST be absolute. The CLI resolves a relative path against its own
    # browser process, not your shell, so `foo.png` is written somewhere you will never
    # find it — and the command still exits 0.
    SHOT="$PWD/$OUT/${SLUG}-${W}w.png"
    $PW screenshot --filename "$SHOT" --full-page --hires >/dev/null 2>&1

    # Check the artefact, not the exit code. Exit 0 here means "the command ran",
    # not "a screenshot exists" — the two came apart on the relative-path bug above.
    if [ -s "$SHOT" ]; then
      echo "  shot ${W}w -> $OUT/${SLUG}-${W}w.png ($(wc -c <"$SHOT" | tr -d ' ') bytes)"
    else
      echo "  shot ${W}w FAILED — no file at $SHOT (command exited 0 regardless)"
    fi
  done

  # Several commands emit a .yml snapshot, and an unchanged page may be deduplicated,
  # so counting new files gives false negatives. Report the newest non-empty one.
  $PW snapshot >/dev/null 2>&1
  SNAP=$(find "$OUT" -name '*.yml' -size +0 2>/dev/null | sort | tail -1)
  if [ -n "$SNAP" ]; then
    echo "  a11y snapshot -> $SNAP"
    echo "     unnamed interactive elements (a11y defects):"
    grep -nE '^\s*-\s*(button|link|textbox|checkbox|combobox)\s*\[ref=' "$SNAP" \
      | sed 's/^/       /' || echo "       none"
  else
    echo "  snapshot produced no file"
  fi

  echo "  --- console (warning and above) ---"
  $PW console warning 2>&1 | head -40
done

echo
echo "=== ARTIFACTS ==="
find "$OUT" -type f -newermt '-5 minutes' 2>/dev/null | sort | tail -30
echo "Read the console output first. Open screenshots only where it points."

# Guards: the script reported ALREADY_RUNNING in an empty directory because macOS
# ControlCenter answers on :5000. It must report evidence, never a verdict.
S="$SKILLS_DIR/frontend-verify/scripts/dev-server.sh"
enter_testrepo || return
printf '{"scripts":{"dev":"vite"}}' > package.json

out=$("$S" 2>&1)
assert_absent   "never claims a server is running" "$out" "ALREADY_RUNNING"
assert_contains "reports what this project starts" "$out" "npm run dev"
assert_contains "hands the judgment to the reader" "$out" "Judge these yourself"
cd /; rm -rf "$TESTDIR"

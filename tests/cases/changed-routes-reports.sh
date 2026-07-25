# Guards: (a) a sed delimiter collision made every pattern fail to parse, and
# (b) hardcoded per-framework mapping returned empty for frameworks not on the list.
# The script must REPORT files and routing locations, never an empty guess.
S="$SKILLS_DIR/frontend-verify/scripts/changed-routes.sh"
enter_testrepo || return
mkdir -p src/app/dashboard src/components/ui
echo a > src/app/dashboard/page.tsx; echo b > src/components/ui/button.tsx
git add -A; git commit -q -m base
git switch -q -c feat
echo c >> src/app/dashboard/page.tsx; echo d >> src/components/ui/button.tsx
git commit -qam change

out=$("$S" main)
assert_contains "lists the changed route file"  "$out" "src/app/dashboard/page.tsx"
assert_contains "flags shared components"       "$out" "src/components/ui/button.tsx"
assert_contains "points at routing locations"   "$out" "ROUTING CONFIG"
assert_absent   "no sed parse errors"           "$out" "unbalanced"
assert_absent   "no sed parse errors (2)"       "$out" "RE error"
cd /; rm -rf "$TESTDIR"

# Guards: BASE..HEAD is empty when HEAD *is* BASE, so a handoff written on main — the
# common case at the end of a piece of work — recorded no history at all.
S="$SKILLS_DIR/handoff/scripts/gather-state.sh"
enter_testrepo || return
echo x > f.txt; git add -A; git commit -q -m "real work"

out=$("$S")
assert_contains "on main, still reports commits" "$out" "real work"

git switch -q -c feat; git commit -q --allow-empty -m "branch work"
out=$("$S")
assert_contains "on a branch, reports branch commits" "$out" "branch work"
cd /; rm -rf "$TESTDIR"

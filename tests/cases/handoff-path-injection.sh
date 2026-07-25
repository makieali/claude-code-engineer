# Guards: a handoff title is user input. Building the path model-side would interpolate
# untrusted text into a shell command. The allowlist is what prevents that.
S="$SKILLS_DIR/handoff/scripts/handoff-path.sh"
enter_testrepo || return

out=$("$S" 'evil; rm -rf /')
assert_absent "strips shell metacharacters" "$out" ';'
assert_absent "strips spaces"               "$out" 'evil;'
assert_contains "keeps the readable part"   "$out" 'evil-rm-rf'

out=$("$S" '$(whoami)')
assert_absent "strips command substitution" "$out" '$('

out=$("$S" '../../escape')
assert_absent "no path traversal survives"  "${out#*/plans/handoffs/}" '/'

out=$("$S" '')
assert_contains "empty title falls back"    "$out" 'untitled'

a=$("$S" 'dup'); b=$("$S" 'dup'); touch "$a"
c=$("$S" 'dup')
assert_eq "append-only: never returns an existing path" "$([ "$c" = "$a" ] && echo collide || echo unique)" "unique"
cd /; rm -rf "$TESTDIR"

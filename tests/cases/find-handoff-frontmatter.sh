# Guards: values carried a leading space (BRANCH_THEN= main), breaking any consumer.
S="$SKILLS_DIR/resume-work/scripts/find-handoff.sh"
enter_testrepo || return
mkdir -p plans/handoffs
printf -- '---\nbranch: main\ndate: 2026-01-01T00:00:00Z\nstatus: blocked\n---\n' \
  > plans/handoffs/20260101-000000-x.md

out=$("$S")
assert_contains "no leading space on branch" "$out" "BRANCH_THEN=main"
assert_contains "no leading space on status" "$out" "STATUS=blocked"
assert_absent   "no space after ="           "$out" "BRANCH_THEN= "

out2=$(cd /tmp && "$S" 2>&1 || true)
assert_contains "handles no-handoffs cleanly" "$out2" "NO_HANDOFFS"
cd /; rm -rf "$TESTDIR"

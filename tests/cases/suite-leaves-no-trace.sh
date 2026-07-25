# Guards: an earlier harness bug ran every case inside this repo instead of a temp dir,
# creating plans/ and src/ fixtures and even committing them. The suite must not modify
# the tree it is testing.
REPO_ROOT=$(cd "$SKILLS_DIR/.." && pwd)
before=$(cd "$REPO_ROOT" && git status --porcelain | sort)
untracked_before=$(cd "$REPO_ROOT" && git ls-files --others --exclude-standard | sort)

# Cases run before this one in the same suite; if any of them dirtied the repo, it shows here.
after=$(cd "$REPO_ROOT" && git status --porcelain | sort)
assert_eq "suite does not dirty the repo it tests" "$after" "$before"

# Fixture directories a runaway case would leave behind.
for d in plans src .worktrees node_modules; do
  assert_no_file "no stray $d/ in repo root" "$REPO_ROOT/$d"
  assert_no_file "no stray $d/ in tests/"    "$REPO_ROOT/tests/$d"
done

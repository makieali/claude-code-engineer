#!/usr/bin/env bash
# Minimal assertion helpers. No dependencies — these must run anywhere the skills do.
set -uo pipefail

PASS=0; FAIL=0
SKILLS_DIR="${SKILLS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills" && pwd)}"

_ok()   { PASS=$((PASS+1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
_no()   { FAIL=$((FAIL+1)); printf '  \033[31m✗\033[0m %s\n' "$1"; [ -n "${2:-}" ] && printf '      %s\n' "$2"; }

assert_eq()       { [ "$2" = "$3" ] && _ok "$1" || _no "$1" "expected '$3', got '$2'"; }
assert_contains() { case "$2" in *"$3"*) _ok "$1";; *) _no "$1" "output missing '$3'";; esac; }
assert_absent()   { case "$2" in *"$3"*) _no "$1" "output should NOT contain '$3'";; *) _ok "$1";; esac; }
assert_exit()     { [ "$2" = "$3" ] && _ok "$1" || _no "$1" "expected exit $3, got $2"; }
assert_file()     { [ -s "$2" ] && _ok "$1" || _no "$1" "no non-empty file at $2"; }
assert_no_file()  { [ ! -e "$2" ] && _ok "$1" || _no "$1" "unexpected file at $2"; }

# A scratch git repo, because most of these scripts only make sense inside one.
#
# This function CANNOT cd for you: it is called as `d=$(mktestrepo)`, which runs in a
# subshell, so any cd inside it is discarded. An earlier version tried, and the cases
# silently ran inside this repo instead — creating plans/ and a stray branch in the very
# tree under test. Callers must `cd "$d"` themselves, and enter_testrepo enforces it.
mktestrepo() {
  d=$(mktemp -d)
  ( cd "$d" && git init -q . \
    && git config user.email t@t && git config user.name t \
    && git commit -q --allow-empty -m init && git branch -M main ) >/dev/null 2>&1
  printf '%s' "$d"
}

# Use this instead of a bare cd — it refuses to proceed if we are not somewhere disposable.
# Sets TESTDIR and cds into it. Deliberately does NOT echo the path: capturing output
# with $( ) would put the cd back inside a subshell, which is the exact bug above.
# Cases are sourced, so this cd persists in the caller.
enter_testrepo() {
  TESTDIR=$(mktestrepo)
  cd "$TESTDIR" || { _no "setup" "could not enter $TESTDIR"; return 1; }
  case "$PWD" in
    /tmp/*|/private/tmp/*|/var/folders/*) return 0 ;;
    *) _no "setup" "refusing to run outside a temp dir (in $PWD)"; return 1 ;;
  esac
}

summary() {
  echo
  printf '  %s passed, %s failed\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]
}

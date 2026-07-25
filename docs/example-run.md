# A real run, end to end

The pipeline applied to a real open-source repository, with the defects it found recorded
rather than tidied away. Everything below happened; nothing is illustrative.

**Target:** [`sindresorhus/yocto-queue`](https://github.com/sindresorhus/yocto-queue) — 90
lines, real `ava` + `tsd` suite.
**Task:** add `peekLast()`, returning the tail value without removing it.
**Result:** 50 lines across 5 files, 8 tests green, `tsd` green, merged.

---

## 1. `/architect` — plan first

Orientation read the manifest rather than assuming a stack, and found something that
shaped the whole plan: **`xo` fails three ways on the pristine tree**, which is why the
project's own `test` script omits it.

So `lint_command` was recorded as `null`. Had it been set to `npx xo`, every phase would
have failed on pre-existing debt and burned the executor's two fix attempts on someone
else's lint errors.

Three phases, decomposed so the machinery was actually exercised:

| Phase | Owns | Depends on | Parallel | Isolation |
|---|---|---|---|---|
| 1 type-contract | `index.d.ts`, `index.test-d.ts` | — | no | branch |
| 2 implementation | `index.js`, `test.js` | 1 | yes | worktree |
| 3 docs | `readme.md` | 1 | yes | worktree |

Phases 2 and 3 touch disjoint files, so there is no conflict zone — that is what makes them
genuinely parallel rather than nominally parallel.

## 2. `/executor` — verified, not asserted

Phase 1 landed the contract before any implementation existed. The interesting moment was
proving the verify command could actually fail:

```
assert the WRONG type   -> tsd exit 1
assert the right type   -> tsd exit 0
```

A verify command that has never failed is not a gate.

## 3. `/reviewer` — found a flaw in the plan

Mechanical evidence first: `ava` 0, `tsd` 0. Then two mutations of the declaration, both
caught. Then a finding the executor could not have produced, because it required standing
outside the phase:

> After phase 1, `index.d.ts` declares `peekLast()` and `index.js` has no such method.
> Verified at runtime: `typeof queue.peekLast === 'undefined'`, calling it throws.
> `tsd` passes because it checks declarations against assertions, never against the
> implementation.

Phase 1 was independently green while shipping a type declaration with nothing behind it.
**Verdict: approved with notes**, and the note was a defect in the decomposition — mine.

The review also recorded its own compromise, because it ran in the session that wrote the
code: `reviewer_independence: VIOLATED`, verdict provisional. That is the honest form when
a fresh context is not available.

## 4. Parallel phases — the part most likely to be theatre

Two worktrees, two branches, two state files. After both merged:

```
phase-1.json         needs_review
phase-1.review.json  approved_with_notes
phase-2.json         needs_review
phase-3.json         needs_review
```

All four survived. The reviewer never touched the executor's file — single-writer held.

**The rationale behind that design was partly wrong, and testing corrected it.** Two
processes doing read-modify-write on one JSON file, 60 updates each: both crashed on
`JSONDecodeError` and left the file invalid — a *torn write*, worse than the lost update
originally claimed. And two executors on separate git branches editing the same file on
different lines merge cleanly. So the danger is concurrent writes to one path, not the
merge, and the fix needs **one writer per file *and* one worktree per phase.**

## 5. Mutation checks — the tests earned it

Three deliberate breakages of the implementation, all caught:

| Mutation | Result |
|---|---|
| return `#head` instead of `#tail` | ava exit 1 |
| `return this.dequeue()` (mutates) | ava exit 1 |
| drop the empty-queue guard | ava exit 1 |

Green tests prove the suite ran. Only mutation proves it checks anything.

---

## What broke, and what it changed

Five defects, none of them in the logic — every one at a seam between two skills:

| Defect | Fix |
|---|---|
| Executor committed `exit_code: 0` for a task that never ran; recorded sha pointed at the previous HEAD | `/executor` states that state files are self-reported and nothing validates them; `/reviewer` re-runs every command |
| `verify_command` that could never match — `grep '### peekLast()'` against a readme using `` #### `.peek()` `` | `/architect` must check verify commands against the real file |
| Uncommitted `plans/` blocked the executor's clean-tree gate | `/architect` commits the plan before handing off |
| Worktrees outside the repo cannot resolve gitignored dependencies | `.worktrees/phase-N` is required, with the reason |
| Reviewer independence violated with no protocol | `/reviewer` defines the degraded path and marks verdicts provisional |

## Try it

```bash
git clone --depth 1 https://github.com/sindresorhus/yocto-queue && cd yocto-queue && npm install
```

Then `/architect` a small addition, `/executor` a phase, `/reviewer` it. The whole loop is
about fifteen minutes on a repo this size, and it is the fastest way to find out whether
this pipeline suits how you work.

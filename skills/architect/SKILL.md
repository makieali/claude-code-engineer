---
name: architect
description: >
  Analyzes a problem and generates a phased execution plan with progress
  tracking, shared contracts, dependency graphs, per-phase isolation, and
  task-level detail. Use when tackling any large feature, refactor,
  migration, or complex fix.
  Trigger: "plan this", "break this down", "architect this", "create a plan".
---

# Architect — Problem Analysis & Plan Generation

You are a senior software architect. Analyze the problem, read the codebase, and produce a
plan that several agents can execute in parallel without corrupting each other's work or
each other's state.

**This skill writes plans. It does not write implementation code.**

## PRINCIPLES

1. **Never one-shot** — small, incremental, independently testable steps
2. **Leave breadcrumbs** — every file gives the next agent full context without the session
3. **JSON for state, markdown for reasoning** — agents corrupt checkboxes; JSON survives
4. **One writer per file** — the entire reason parallel phases are safe
5. **External verification** — every task carries a command that can fail honestly
6. **Contracts first** — every interface defined before any implementation starts
7. **Honest confidence** — low confidence is a flag for a human, not a guess to paper over

---

## MODEL ROUTING

| Role | Used here for | Effort |
|---|---|---|
| **orchestrator** | the planning itself — decomposition, contracts, risk | `high` |
| **executor** | codebase reconnaissance feeding the plan | `medium` |
| **bulk** | file counting, manifest detection, inventory sweeps | `low` |

*Mapping as of 2026-07-25 — re-check on every model release:* orchestrator `claude-opus-5`,
executor `claude-sonnet-5`, bulk `claude-haiku-4-5`.

Planning is judgment work and belongs on the strongest model you have. Reconnaissance is
not — set `model` explicitly on recon spawns or they run at planning rates.

---

## STEP 1: DEEP ANALYSIS

If `/investigate` already ran, **start from its report** rather than re-reading the
codebase. That is what it is for, and re-deriving it burns context you will need for the
contracts.

Otherwise, orient without assuming a stack:

```bash
# What is at the root? Read it and recognise the stack. Do NOT match against a fixed
# list of manifest names — there is always one nobody thought of (deno.json, bun.lockb,
# build.zig, rebar.config, dune-project, Package.resolved...). You know what a manifest
# looks like; look.
ls -a

# Layout, languages, tests
git ls-files | sed 's|/[^/]*$||' | sort | uniq -c | sort -rn | head -20
git ls-files | grep -oE '\.[A-Za-z0-9]+$' | sort | uniq -c | sort -rn | head -15
git ls-files | grep -iE '(^|/)(tests?|spec|__tests__)/|[._](test|spec)\.' | head -20

# How this project actually builds and tests — read the scripts, do not assume
cat Makefile Taskfile.yml justfile 2>/dev/null | head -40

git log --oneline -20
ls .github/workflows .gitlab-ci.yml Jenkinsfile .circleci 2>/dev/null
```

**Derive the three commands from what you find** — `test_command`, `lint_command`,
`build_command`. Do not write `npm test` into a Gradle project. If a project has no lint or
no build step, record `null` rather than inventing one; the executor and reviewer both
branch on that.

Then ask:
- What is the smallest change that delivers value?
- What currently depends on the code being changed?
- Are there migrations or data transformations? What is the rollback?
- Does anything need a feature flag to ship safely?
- Which files will two phases both want to touch?

---

## STEP 2: PLAN STRUCTURE

```
plans/{problem-slug}/
├── plan.md                      # contracts, decisions, risks — the reasoning
├── progress.json                # the immutable plan — written once, here
├── state/                       # mutable status, one writer per file
│   ├── phase-1.json             #   ← written only by the executor holding phase 1
│   └── phase-1.review.json      #   ← written only by the reviewer
├── reviews/
│   └── phase-1-cycle-1.md
└── phases/
    └── phase-1-{name}.md        # the detailed brief for phase 1
```

Slug is lowercase-kebab-case: `add-rate-limiting`, `auth-refactor`.

### Why state is split out — read this before changing it

`progress.json` used to hold both the plan and the live status. Two executors then read it,
modify their slice, and write it back — concurrently.

Measured, not assumed. Two processes doing read-modify-write on one JSON file, 60 updates
each: **both crashed on `JSONDecodeError` and the file was left invalid.** The failure is a
torn write, not merely a lost update — a reader hitting the file mid-write gets a truncated
document. Same test with one file per writer: 120/120 updates recorded, no corruption.

One caveat worth stating, because it cuts against the obvious reading: if the two executors
are on **separate git branches**, git merges edits to the same file cleanly as long as they
land on different lines. The danger is not the merge. It is two agents writing the same path
in the same working tree at the same time — which is exactly what happens when phases run
without worktree isolation.

So the fix is two-part, structural rather than procedural, and both halves are load-bearing:
**one writer per file**, and **one working tree per phase.** `progress.json` is immutable
after planning; each phase's mutable state lives in its own file. Executors write
`state/phase-N.json`. Reviewers write `state/phase-N.review.json`. `/driver` reads everything
and writes neither. No file ever has two writers, so no lock is needed.

---

## STEP 3: WRITE progress.json

Written once by this skill. **Nothing downstream ever modifies it.** If it turns out to be
wrong, that is a re-plan, not an edit.

```json
{
  "project": "{problem-slug}",
  "created": "YYYY-MM-DD",
  "summary": "One line",
  "commands": {
    "test": "npm test",
    "lint": "npm run lint",
    "build": "npm run build"
  },
  "base_branch": "main",
  "phases": [
    {
      "id": 1,
      "name": "Phase name",
      "depends_on": [],
      "parallel_safe": true,
      "isolation": "worktree",
      "branch": "plan/{slug}/phase-1",
      "confidence": "high",
      "load_bearing": false,
      "tasks": [
        {
          "id": "1.1",
          "name": "Task name",
          "files_affected": ["src/path/file.ts"],
          "has_test": true,
          "verify_command": "npm test -- auth/token",
          "commit_message": "feat(auth): add token validation",
          "blocks": ["1.2"]
        }
      ]
    }
  ],
  "contracts": {
    "new_types": ["IAuthToken"],
    "modified_types": ["IUser — adding tokenExpiry: number | null"],
    "new_endpoints": ["POST /api/auth/refresh"],
    "db_migrations": ["users.token_expiry — nullable bigint"],
    "new_env_vars": ["RATE_LIMIT_MAX=100"]
  },
  "conflict_zones": [
    {
      "file": "src/middleware/auth.ts",
      "touched_by_phases": [2, 3],
      "resolution": "Phase 2 lands first; phase 3 rebases before its final commit"
    }
  ]
}
```

**Fields that matter and are easy to get wrong:**

- `verify_command` — **run it, or read the file it targets, before writing it into the
  plan.** A command that can never match is worse than no command: the executor burns its
  fix attempts, records a failure it cannot act on, and blocks a phase on a typo. Observed:
  a docs task shipped `grep -q '### peekLast()'` against a readme that uses
  `` #### `.peek()` `` — four hashes, backticks, leading dot. It could never pass.
- `blocks` — task IDs that cannot start if this task fails. This is what lets the executor
  decide whether a failure stops the phase or is survivable. Without it, a failed task is
  followed by tasks built on ground that is not there.
- `isolation` — `"worktree"` for any `parallel_safe` phase. Each executor gets its own git
  worktree, so two phases cannot fight over the index or the working tree. `"branch"` is
  enough for sequential phases. Never `"none"` on shared code.
- `load_bearing` — `true` for auth, payments, migrations, external contracts, anything with
  data-loss blast radius. The reviewer runs a three-lens adversarial pass on these and a
  single pass on everything else.
- `confidence` — `low` means a human decides before execution starts. Say why in `plan.md`.

**Status values, used only in `state/`:** `not_started` `in_progress` `needs_review`
`needs_fixes` `blocked` `failed` `done`. The executor never writes `done` — the reviewer
sets it after checking the work.

`needs_fixes` and `done` are **never written** into `phase-N.json` — they are derived by
`/driver` from the review file, because the reviewer is not allowed to write the executor's
file. An executor's phase legitimately ends at `needs_review` and stays there.

---

## STEP 4: WRITE plan.md AND THE PHASE FILES

`plan.md` carries the reasoning — problem, current state, desired end state, key decisions,
**ruled out**, risks, shared contracts, phase overview, dependency graph, conflict zones,
rollback. Each `phases/phase-N-{name}.md` carries the executable brief for one phase:
objective, pre-conditions, the contracts it uses copied in verbatim, files affected, one
block per task, phase verification, rollback, and the DO/DON'T notes.

Full templates for both: [`references/templates.md`](references/templates.md).

Two things there are load-bearing rather than decorative:

- **Ruled out** — the section every automatic summary loses, and the reason a fresh session
  re-tries what already failed.
- **Shared Contracts is the source of truth.** Changing it mid-flight invalidates work already
  built against it, so an executor that needs a change stops and reports; it never edits.

A phase file must be executable by an agent that has never seen this conversation. If it
needs you to explain it, it is not finished.

## COMMIT THE PLAN BEFORE HANDING OFF

```bash
git add plans/{slug} && git commit -m "chore: add plan for {slug}"
```

`/executor` requires a clean working tree at Step 1. An uncommitted `plans/` directory is
untracked cruft that blocks it on the first check — found by running the pipeline, not by
reading it.

## OPTIONAL: JUDGE-PANEL MODE

For plans that are expensive to get wrong — migrations, architecture with no clean answer,
anything irreversible — do not iterate on one plan. Generate several independently from
different angles, score them with independent judges, and synthesize from the winner while
grafting the specific strengths the judges named in the others.

Do not average the plans together; you get the weaknesses of all of them. The script is in
[`references/judge-panel.md`](references/judge-panel.md).

## CONTEXT DISCIPLINE

Planning is the highest-value thinking in the pipeline and it degrades with everything you
read before it.

- Plan in a **fresh session**, ideally from an `/investigate` report rather than raw files.
- The plan on disk is the durable artifact. Once written, this session can end — every
  executor starts from the files, not from you.
- If you find yourself deep in implementation detail, you are executing, not planning. Write
  it into the phase file and move on.

---

## AFTER THE PLAN

Tell the user:

1. Review `plan.md` — **Shared Contracts** and **Risks** especially. Contracts are expensive
   to change once execution starts.
2. Review 🔴 low-confidence items. Those want a human decision now, not a guess later.
3. Execute: `/executor` per phase, parallel where `parallel_safe` and dependencies allow.
4. Validate: `/reviewer` after each phase.
5. Or hand the whole thing to `/driver`, which reads state and sequences it for you.

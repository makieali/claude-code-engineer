# Architect — plan.md and phase file templates

```markdown
# {Title}

> {date} · live status: `state/` · this file is reasoning, not state

## Problem
{What is broken or missing — specific, with file paths}

## Current State
{Architecture and patterns as they exist today}

## Desired End State
{Measurable and testable. What does done look like, and how is it proven?}

## Key Decisions
| Decision | Chosen | Why | Rejected alternative |
|---|---|---|---|

## Ruled Out
{Approaches considered and rejected, and why. This is the section a summary always loses,
and its absence is why a fresh session re-tries what already failed.}

## Risks
| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|

## Shared Contracts — SOURCE OF TRUTH
{Full definitions. Every agent building against these must match exactly. Types with
field names, optionality and nullability. Endpoints with method, path, request and
response shapes. Migrations in execution order. Env vars with example and required flag.}

**Changing anything in this section mid-flight invalidates work already built against it.
An executor that needs a change here stops and reports; it does not edit.**

## Phase Overview
| # | Name | Depends on | Parallel | Isolation | Load-bearing | Confidence |
|---|---|---|---|---|---|---|

## Dependency Graph
{Execution order, and which phases can genuinely run at once}

## Conflict Zones
{Files two phases both touch — who owns what, and the merge order}

## Rollback
{Per phase, plus the nuclear option}
```

---

## STEP 5: WRITE PHASE FILES

Each `phases/phase-N-{name}.md` must be executable by an agent that has never seen this
conversation.

```markdown
# Phase {N}: {Name}

> Depends on: {list} · Parallel safe: {yes/no} · Isolation: {worktree/branch}
> Branch: `plan/{slug}/phase-{N}` · Confidence: 🟢/🟡/🔴

## Objective
{What this phase does, and why it is a separate phase}

## Pre-Conditions
- [ ] {Specific command that proves the dependency is met}

## Contracts This Phase Uses
{Copied verbatim from plan.md — the executor should not have to go looking}

## Files Affected
| File | Action | What changes |
|---|---|---|

---

### Task {N}.1: {Name}
**Files:** `src/path/file.ts`
**Blocks:** {task IDs that cannot proceed if this fails, or "none"}

**What to do:** {Specific enough that any engineer could follow it}

**Implementation notes:** {Patterns to follow, pseudo-code, the existing function to copy}

**Edge cases:** {The real ones for this task — null inputs, timeouts, races, backward
compatibility, large inputs. Not a generic checklist.}

**Verify:** `{command}`
**Commit:** `{conventional commit message}`

---

## Phase Verification
```bash
{phase-specific tests}
{test_command} && {lint_command} && {build_command}
```

## Rollback
```bash
git revert {range}     # or: discard the worktree, the branch was never merged
```

## Notes for the Executing Agent
**DO:** {conventions, the existing pattern to match, context that is not obvious}
**DON'T:** {mistakes available here, files not to touch, assumptions that are wrong}
```

---

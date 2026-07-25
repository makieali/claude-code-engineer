---
name: resume-work
description: >
  Restores working context after a /clear or /compact by reading the most
  recent session handoff plus current git state, then reports where things
  stand and what the next step is. Use at the start of a session, after
  clearing or compacting, when picking up work from a previous day, or when
  taking over someone else's branch.
  Trigger: "resume", "pick up where we left off", "what was I doing",
  "restore context", "continue from the handoff", "catch me up".
---

# Resume Work — Reload State From Disk

The other half of `/handoff`. Reads the written record rather than a summary of a summary.

## Step 1: Find the handoff

```bash
~/.claude/skills/resume-work/scripts/find-handoff.sh            # newest for the current branch
~/.claude/skills/resume-work/scripts/find-handoff.sh --all      # every branch, newest first
```

Then read the file it prints. Read it **whole** — the `Ruled out` section is usually near
the bottom and it is the most valuable part.

No handoff found? Say so plainly and fall back to git: `git log --oneline -15`,
`git status`, `git diff --stat`. A reconstruction from history is worth less than a
handoff, so say which one you are working from.

## Step 2: Check the record against reality

The handoff describes the world when it was written. Verify before trusting it:

```bash
git rev-parse --abbrev-ref HEAD          # same branch?
git status --short                       # same files dirty?
git log --oneline -5                     # commits since?
```

Reconcile out loud when they disagree — someone else may have pushed, or you may have
committed after writing it. **The repo is the truth; the handoff is the intent.** Where they
conflict, say so rather than silently trusting either.

## Step 3: Report, then stop

```
RESUMED — <title>
  Handoff:  <path>  (<age>)
  Branch:   <branch>   <n> commits since the handoff
  Dirty:    <n> files

  Stood at:  <one line>
  Ruled out: <one line — so it is in context before any suggestion>
  Blockers:  <or "none">

  → Next: <the next step, verbatim from the handoff>
```

Then **stop and wait.** Do not start the next step. Resuming is loading state, not
resuming execution — the user may have changed their mind since writing it, and that is
exactly the moment to find out.

## Rules

- **Surface `Ruled out` before proposing anything.** Its whole purpose is stopping a fresh
  session from re-walking dead ends. Reading it after you have already suggested an approach
  is too late.
- **Report the handoff's age.** One from three weeks ago on a branch with twenty new commits
  is archaeology, not state. Say so.
- **Never mark a handoff done or delete it.** They are append-only. `/handoff` writes the
  next one.
- **Don't re-read every file it mentions.** It names paths so you can go to them when the
  work needs it, not so you can reload the whole session's reads into a clean window. That
  would undo the reset you just paid for.

## Related

- `/handoff` — writes the file this reads
- `/driver` — if the work is a `/architect` plan, read `plans/{slug}/state/` too; the
  handoff covers session narrative, not plan state

---

<sub>Script paths above assume a user-level install (`~/.claude/skills/`). Installed as a
plugin or per-project, the scripts still sit beside this file — swap the prefix for
`${CLAUDE_PLUGIN_ROOT}/skills/resume-work` or `.claude/skills/resume-work` respectively.</sub>

---
name: handoff
description: >
  Writes a session handoff to disk before a context reset — what's done,
  what changed, what was decided, what was ruled out, and the single next
  step — then tells you whether to /clear or /compact. Use when a session
  is getting long or slow, before compacting, at the end of a work block,
  or when handing work to another person or session.
  Trigger: "write a handoff", "save progress", "save state", "session is
  getting slow", "before I compact", "wrap up", "I'm stopping here".
---

# Handoff — Write State Down Before You Lose It

Quality degrades as context grows, well before the window is full, and worst for
information in the middle of a long session. The model summarising at the end is already
impaired by the thing you are trying to escape.

So write the handoff **deliberately, while judgment is intact** — not when auto-compact
fires.

**HARD GATE: this skill writes one file. It does not change code, run tests, or commit.**

## The loop

```
/handoff  →  writes plans/handoffs/<date>-<slug>.md
          →  tells you: /clear or /compact
   you    →  run it
/resume-work → reads the newest handoff, you carry on
```

**You run the reset, not this skill.** `/clear` and `/compact` are REPL commands with no
tool behind them — no skill can invoke them. Anything claiming otherwise is guessing.

---

## Step 1: Gather state

```bash
~/.claude/skills/handoff/scripts/gather-state.sh
```

Reads branch, status, diff stat, staged stat, recent log, and files touched. If the script
is missing, run the equivalents by hand — but prefer the script; it keeps its own output
out of context.

## Step 2: Write the file

Path is computed in bash, never assembled in the prompt — a title you pass through is
untrusted input and the allowlist is what keeps it out of the shell.

```bash
~/.claude/skills/handoff/scripts/handoff-path.sh "<title>"    # prints the safe path; use it verbatim
```

Files are **append-only**. Never overwrite an existing handoff, never delete one. Each save
is a new file, and the sequence is the record.

Template:

```markdown
---
branch: <branch>
date: <ISO 8601>
status: in-progress | blocked | complete
files_touched:
  - <path>
---

# Handoff — <title> — <date>

## Where things stand
One paragraph. What is done, what is half-done.

## What changed
Files, commands run, config values set. Not "fixed the search".

## Decisions and why
The reasoning, not just the outcome.

## Ruled out
Approaches tried and rejected, and why.

## Blockers
Open questions, decisions needed from a human.

## Next step
One action, specific enough to start on cold.
```

### Ruled out is the section that matters

It is the one automatic summaries reliably lose, and its absence is exactly why a fresh
session cheerfully re-tries everything that already failed. If you write nothing else well,
write this well. An empty `Ruled out` on a session that hit dead ends is a bug in the
handoff, not a clean run.

### Next step must be startable cold

"Continue the refactor" is not a next step. "Add the `tenant_id` filter to
`app/api/search.py:88`, then run `pytest tests/test_search.py`" is.

---

## Step 3: Tell the user which reset to run

Pick from what happens next, and say which and why:

| Next work | Command | Why |
|---|---|---|
| Same thread, context is just noisy | `/compact` | Keeps continuity; drops tool output and dead ends |
| New task, or the session is tangled | `/clear` | A fresh window plus the handoff beats a summary of a mess |
| Stopping for the day | `/clear` | Tomorrow's session starts from the file, not from a stale summary |

Rule of thumb: **compact when the thread still matters, clear when it doesn't.** If you have
already compacted once in this session and it is slow again, clear — a summary of a summary
is where detail goes to die.

Then print:

```
HANDOFF WRITTEN
  File:    plans/handoffs/<file>
  Branch:  <branch>
  Files:   <n> touched
  Status:  <status>

  → Run /clear (or /compact), then /resume-work
```

---

## Rules

- **Infer, don't interrogate.** Use git state and the conversation. Ask only if the title
  genuinely can't be inferred.
- **Never modify code.** If work is uncommitted, say so in `What changed` and leave it.
- **Record failures honestly.** A handoff that only lists wins sends the next session into
  the same wall.
- **Always include the branch.** Cross-branch resume depends on it.
- **Don't summarise tool output.** Point at the file or the command. The next session can
  re-run it more cheaply than it can read your paraphrase.

## When not to use this

Short sessions that ended cleanly with everything committed. `git log` is already the
handoff. Writing one for a two-commit session is ceremony.

## Related

- `/resume-work` — reads the newest handoff and restores working context
- Long-running plans have their own state in `plans/{slug}/state/` — this is for the
  session narrative around them, not a replacement

---

<sub>Script paths above assume a user-level install (`~/.claude/skills/`). Installed as a
plugin or per-project, the scripts still sit beside this file — swap the prefix for
`${CLAUDE_PLUGIN_ROOT}/skills/handoff` or `.claude/skills/handoff` respectively.</sub>

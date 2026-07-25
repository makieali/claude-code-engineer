---
name: decision-log
description: >
  Records durable technical decisions with their reasoning, and searches them
  before a settled question gets re-opened. Use when an architectural, scope,
  tooling or vendor choice is made or reversed, when someone asks "why is it
  like this", or before proposing an approach that may already have been
  rejected.
  Trigger: "log this decision", "why did we choose", "did we try", "have we
  decided", "record that we're not doing", "was this considered".
---

# Decision Log — Ruled Out, Made Permanent

A handoff's `Ruled out` section dies with the handoff. A decision log does not.

Without one, a rejected approach comes back every few weeks, gets re-argued from scratch,
and sometimes wins the second time purely because nobody remembers why it lost. The cost is
not the discussion — it is silently reversing a decision that had a good reason.

**Two operations, and the read is the one that matters.**

## Search before proposing

Before proposing an approach, or when a question smells settled:

```bash
grep -il "<term>" docs/decisions/*.md 2>/dev/null | tail -5
```

Anything that hits, read whole. Then:

- **The decision stands** → say so, cite it, move on. Do not re-derive the reasoning.
- **You want to reverse it** → say that explicitly. *"This reverses D-014, which chose X
  because Y; that reason no longer holds because Z."* A silent reversal is the failure this
  file exists to prevent.
- **It is genuinely new** → proceed, and log it when it lands.

## Log when it lands

One file per decision, `docs/decisions/D-NNN-slug.md`, append-only:

```markdown
---
id: D-014
date: 2026-07-26
status: accepted        # accepted | superseded
supersedes:             # D-009, if this reverses one
superseded_by:          # filled in later, never deleted
tags: [storage, api]
---

# D-014 — <the decision in one line>

## Context
What forced a choice. The constraint, not the whole history.

## Decision
What was chosen, stated so someone can act on it without asking.

## Why
The reasoning. This is the part that has to survive — an outcome without its reason
cannot be re-evaluated when conditions change.

## Rejected
| Option | Why not |
|---|---|

## Revisit when
The condition that would make this worth reopening. "When the dataset passes 10M rows",
not "periodically". A decision with no revisit condition is a decision nobody will ever
dare change.
```

## Reversing one

Never edit a decision to say something different — that destroys the record of what was
believed and when. Write a new one, and mark the old:

```bash
# in the old file's frontmatter
status: superseded
superseded_by: D-021
```

The chain is the value. "We chose Postgres, then Dynamo, then Postgres again" tells you far
more than whichever answer is current.

## What earns an entry

**Log:** architecture, data model, tooling and vendor choices, scope cuts, anything
irreversible, and anything you had to argue about.

**Do not log:** turn-level choices, naming, formatting, anything a diff already explains.
A log with forty entries a week is a log nobody reads, which is the same as no log.

The test: *would someone six months from now waste an afternoon rediscovering this?*

## Working rules

- **Reasoning over outcome.** "Chose X" is nearly useless. "Chose X because Y, and Z was
  rejected because W" can be re-evaluated when Y stops being true.
- **Write it when it lands**, not later. Reconstructed reasoning is invented reasoning.
- **Append-only.** Superseding is a new file plus a pointer, never an edit.
- **Cite the ID in commits and PRs** when the change implements a decision. That is what
  makes the log discoverable by someone who has never heard of it.

## Related

- `/handoff` — session narrative. `Ruled out` there is per-session; this is permanent.
- `/architect` — `plan.md` carries a `Ruled Out` section for one plan. Decisions that
  outlive the plan belong here.

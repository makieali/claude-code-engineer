# CLAUDE.md

A starting template for agentic coding agents, updated for current model behaviour.

Drop it in your project root. Merge with your own project instructions — this is a menu,
not a monolith. Delete anything that doesn't apply to you and add your real commands, file
paths, and test gates. Instructions that don't earn their place make the ones that do
harder to follow.

**Keep the whole file short.** Bloated instruction files cause instructions to get
dropped. If a rule must be enforced, use a hook. If it's contextual knowledge, use a
skill. If it's a delegation boundary, use a subagent. If it's a repeatable multi-agent
process, use a workflow. Only always-on guidance belongs here.

---

## Attribution

Sections 1–4 are Forrest Chang's `andrej-karpathy-skills` file, derived from Andrej
Karpathy's January 2026 observations on LLM coding failure modes. Karpathy wrote the
diagnosis; he did not write the file and has not endorsed it.

Sections 5–8 are my amendments for models released since. The original was written against
agents that under-asked and over-built. Current frontier models have a partly inverted
failure profile — they over-verify, over-delegate, and widen scope. The original four still
hold; what follows adjusts for the new failure modes.

---

## 1. Think before coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

*Amendment:* check in only when different readings would produce materially different
work. Routine judgment calls are the agent's to make. On trivial tasks this section costs
more friction than it saves.

## 2. Simplicity first

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked. No abstractions for single-use code.
- No configurability that wasn't requested. No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

The test: would a senior engineer call this overcomplicated?

## 3. Surgical changes

**Touch only what you must. Clean up only your own mess.**

- Don't improve adjacent code, comments, or formatting.
- Don't refactor what isn't broken. Match existing style even if you'd do it differently.
- Notice unrelated dead code → mention it, don't delete it.
- Remove only the imports and variables your own changes orphaned.

The test: every changed line traces directly to the request.

## 4. Goal-driven execution

**Define success criteria. Loop until externally verified.**

- "Add validation" → "write tests for invalid inputs, then make them pass"
- "Fix the bug" → "write a test that reproduces it, then make it pass"

For multi-step work, state a brief plan with a check per step. Strong criteria let the
agent loop independently; weak criteria ("make it work") force constant clarification.

*Amendment:* the original says "loop until verified." Read that as **externally**
verified — see section 5.

---

## 5. Verification is external, never self

The most important update to the original file.

**Delete self-verification instructions.** Current models verify their own work without
being told. "Double-check your answer," "re-verify before responding," and "use a subagent
to check your work" compound with behaviour the model already has: more tokens, no better
outcome. Vendor guidance now explicitly recommends removing them.

**Build external checks instead.** A test suite. A build gate. A lint pass. A score
threshold. An evaluator model on a goal condition. A reviewer agent in a fresh context.
These can fail honestly; a self-check cannot.

> A model cannot be its own referee. Give it a scoreboard.

## 6. Cap delegation, hold scope

Current models delegate more readily than earlier ones, which pays off on genuinely
independent work and wastes money on everything else.

> Delegate to a subagent only for large tasks that are genuinely independent and
> parallelizable, such as a wide multi-file investigation. Do not delegate work you can
> finish yourself in a handful of tool calls, and do not use subagents to verify or
> double-check your own work. If one subagent can complete the task, use one rather than
> several, and keep spawn counts low.

> Deliver what was asked, at the scope intended. If the request seems mistaken or a better
> approach exists, say so in a sentence and continue with the task as asked rather than
> quietly narrowing, widening, or transforming it.

**On code review:** never instruct a reviewer to "only report high-severity issues" or "be
conservative." Current models follow that literally and report less. Ask for everything and
filter in a separate pass.

**Subagent, workflow, or neither.** Three options now, and picking wrong is expensive in
both directions:

- **Neither** — anything you can finish in a handful of tool calls. This is most work.
- **A subagent** — one large, genuinely independent investigation whose file reads you want
  kept out of your own context.
- **A workflow** — a repeatable multi-agent process whose control flow should be
  deterministic: fan out over a known list, verify each result independently, loop until a
  condition is met. Put the branching in code rather than in a prompt. Deterministic control
  flow is also what makes a stop condition provable instead of asserted, which is the whole
  argument of section 5.

**Parallel agents need one writer per file.** Two agents doing read-modify-write on a shared
state file will silently lose one of the writes, and you will not find out until the state
contradicts the work. Give each agent its own file and merge on read, or isolate them —
separate worktrees for agents that touch the same tree. This is structural: no amount of
instructing them to be careful fixes it.

## 7. Model and effort

Two dials, not one. Effort is now the primary cost lever on frontier models — use the
lower levels liberally wherever your evals show quality holds, and reserve the top of the
ladder for long-horizon agentic work.

- **Escalate the model, not the effort.** A fast model at maximum effort usually costs
  more than a stronger model working comfortably, for the same accuracy.
- **Compose, don't default to the biggest model.** Run a strong model as orchestrator —
  planning, arbitrating, synthesizing — and cheaper capable models as executors in their
  own loops. The largest cost win is the cheapest capable executor paired with the
  strongest model as an on-demand advisor, consulted early (before committing to an
  approach) and late (before declaring done). Name roles, not specific models — the tiers
  shift with every release; the pattern doesn't.
- Re-sweep effort settings after every model upgrade. They do not carry over.
- Hold effort constant within a cached session; changing it invalidates the prefix cache.
- Effort controls thinking depth, not visible output length. For shorter responses, ask
  for shorter responses.
- Set the model explicitly on every subagent, or mechanical lanes silently run at
  orchestrator rates.

## 8. Context discipline

Output quality degrades as context grows — measurably, well before the window is full, and
worst for information sitting in the middle of a long session. Bigger windows moved the
cliff; they didn't remove it.

- One session, one piece of work. Open a fresh session for anything unrelated.
- Rewind to a known-good point rather than appending corrections. Corrections accumulate
  as noise.
- Compact deliberately, before the automatic threshold. The model writing the summary is
  already impaired by the time the window is nearly full.
- Commit often with descriptive messages so state is reconstructable after a compaction.

**Write a handoff before ending a session or compacting:**

```markdown
## Handoff — <feature> — <date>

### Where things stand
One paragraph: what's done, what's in progress.

### What changed
Specific files, commands run, config values set. Not "fixed the search."

### Decisions and why
The reasoning, not just the outcome.

### Ruled out
Approaches already tried and rejected, and why.

### Blockers
Open questions and decisions needed.

### Next step
One action, specific enough to start on.
```

`Ruled out` is the section automatic summaries reliably lose, and its absence is why a
fresh session cheerfully re-tries everything that already failed. It is the highest-value
line in the document.

---

## Compact instructions

```
When summarizing this conversation, preserve:
- Decisions and their rationale
- Approaches ruled out, and why
- Exact file paths modified
- Error messages and their fixes
- Any constraint stated once
Summarize exploration and tool output briefly.
```

---

**These guidelines are working if:** diffs contain fewer unnecessary changes, fewer
rewrites are caused by overcomplication, clarifying questions arrive before implementation
rather than after mistakes, and a fresh session can pick up your work without you
re-explaining it.

**A note on maintenance.** Every claim about model behaviour in sections 5–7 comes from
vendor documentation current as of July 2026. Model behaviour changes on a timescale of
weeks. Treat this file as code: review it when you upgrade, and delete what stops being
true. The original version of this file aged in exactly that way, which is the whole point.

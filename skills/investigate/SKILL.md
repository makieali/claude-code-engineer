---
name: investigate
description: >
  Deep multi-perspective codebase investigation. Use when: analyzing
  feasibility of a new feature, auditing code for issues, investigating
  bugs, evaluating technical debt, or assessing any change before
  planning. Dispatches investigations across the dimensions that matter
  for the question asked, refutes every finding before reporting it, and
  synthesizes into one actionable report.
  Trigger: "investigate this", "is this feasible", "analyze my codebase",
  "audit this", "what would it take to", "assess this", "can we do this",
  "deep dive", "research this before we start".
---

# Investigate — Multi-Perspective Codebase Analysis

You are a principal engineer leading a technical investigation. Before anyone writes a plan
or touches code, understand what you are dealing with. Dispatch investigations from
different angles, make each one survive an attempt to refute it, then synthesize.

**Read-only. This skill never edits code.**

## WHEN TO USE THIS

- **Before /architect** — investigate first, plan second
- **Feasibility check** — "can we even do this? what would it take?"
- **Bug investigation** — "why is this happening? what are all the possible causes?"
- **Audit** — "what's wrong with this code? what are we missing?"
- **Tech debt assessment** — "how bad is it? what should we fix first?"

---

## MODEL ROUTING

Roles, not model names — tiers shift with every release, the pattern doesn't. Map these
once and reuse across the pipeline.

| Role | Used here for | Effort |
|---|---|---|
| **orchestrator** | dimension selection, synthesis, final verdict | `high` |
| **executor** | the dimension investigations themselves | `medium` |
| **bulk** | orientation sweeps, file counting, grep passes | `low` |

*Mapping as of 2026-07-25 — re-check on every model release:* orchestrator `claude-opus-5`,
executor `claude-sonnet-5`, bulk `claude-haiku-4-5`.

**Set `model` explicitly on every spawn.** Omitting it inherits the orchestrator's rate,
which silently prices six mechanical lanes at orchestrator cost. Note that the cheapest
tier may not support the effort parameter at all — check before setting it.

---

## STEP 1: ORIENT (language-agnostic)

Do not assume a stack. Detect it.

```bash
# What is at the root? Read it and recognise the stack. Do NOT match against a fixed
# list of manifest names — there is always one nobody thought of (deno.json, bun.lockb,
# build.zig, rebar.config, dune-project, Package.resolved...). You know what a manifest
# looks like; look.
ls -a

# Source layout — top directories by file count
git ls-files | sed 's|/[^/]*$||' | sort | uniq -c | sort -rn | head -20

# Which languages are actually here, most common first
git ls-files | grep -oE '\.[A-Za-z0-9]+$' | sort | uniq -c | sort -rn | head -15

# Tests
git ls-files | grep -iE '(^|/)(tests?|spec|__tests__)/|[._](test|spec)\.' | head -20

# History and CI
git log --oneline -20
ls .github/workflows .gitlab-ci.yml Jenkinsfile .circleci azure-pipelines.yml 2>/dev/null
```

Not a git repo? Substitute `find . -type f -not -path './.git/*' -not -path './node_modules/*'`
for `git ls-files` throughout.

Read 3–5 core files the layout points at. Orientation reads are not substantive work — do
not report on them, use them to aim.

---

## STEP 2: SELECT DIMENSIONS (do not spawn all six by default)

Six agents on a one-file bug is waste, not rigour. Weight the dimensions by the question,
then spawn only what earns a lane.

| Investigation type | Spawn as own lane | Fold into one sweep lane | Skip |
|---|---|---|---|
| **Feature feasibility** | feasibility, architecture, effort | risk | perf, security |
| **Bug investigation** | architecture, risk | performance | effort, feasibility |
| **Audit** | security, performance, risk | architecture | effort, feasibility |
| **Tech debt** | architecture, effort | risk | perf, security, feasibility |
| **Pre-migration** | feasibility, effort, risk | architecture | perf, security |

**Rule:** a dimension gets its own lane only if it is load-bearing for the question. Anything
secondary is folded into a single sweep agent asked to cover both cheaply. If one agent can
answer the whole question, use one — spawn count is a cost, not a quality signal.

Override the table when the user's problem statement obviously demands it (a payments change
gets a security lane regardless of type).

### The dimensions

**Architecture** — how does this fit what we already have? Structure, layers, dependency
graph, where the change lands, what's reusable, what conventions bind it, is there a similar
feature to learn from.

**Risk** — what breaks? Existing functionality, data integrity, migrations, third-party
version conflicts, concurrency, backward compatibility, deploy and rollback, what happens
when this fails in production at 3am.

**Performance** — N+1 queries, unbounded fetches, missing indexes, memory growth, blocking
work on the main thread or event loop, behaviour at 10× and 100× load, cache invalidation.

**Security** — input validation at boundaries, authn/authz gaps, injection and XSS/CSRF/SSRF
vectors, secret handling, dependency CVEs, PII in logs, privilege escalation, rate limiting.

**Feasibility** — framework and API limits, infra caps and cost, do third parties support
what we need, do we have the data, blocking tech debt, simpler alternatives, what's already
been tried (check git history and closed PRs).

**Effort** — files changed, files created, tests needed, migrations, config and infra, docs,
dependencies, complexity per component, and hidden work: the refactor that has to happen
first and the test gaps that have to be filled.

---

## STEP 3: RUN THE INVESTIGATION

Each investigator must return **evidence, not opinion**. "I think this might be slow" is
useless. "`src/api/search.ts:47` runs a `SELECT *` with no `LIMIT` inside a `forEach`" is
actionable. No `file:line`, no finding.

Then every finding faces a refuter before it reaches the report. A finding nobody tried to
kill is a guess with formatting.

### Workflow mode (preferred — deterministic, and the cross-analysis becomes code)

Schema-forced findings mean corroboration is a `Set` operation over structured data, not a
model re-reading six reports and guessing where they agree. Refutation runs as a `pipeline`,
so the architecture lane's findings are being attacked while the security lane is still
reading — a barrier there would waste the fast lanes for nothing.

Script: [`references/workflow.md`](references/workflow.md).

### Manual mode (no workflow available)

**Spawn each dimension as a subagent even without a workflow.** That is what keeps their
reads out of your window, and it is what makes a refuter independent — an agent that never
saw the finding being formed is a genuinely different reader. Give it the claim and the
evidence, not your reasoning.

Same shape, run by hand: spawn the selected dimensions with `model` set explicitly, collect
their findings, then spawn one refuter per finding before writing anything up. If you are
doing this in-context rather than with subagents, still separate the passes — find
everything first, refute second, filter third. Collapsing them lets the finder grade its own
work.

---

## STEP 4: SYNTHESIZE

Do not staple the reports together. Look for:

- **Corroboration** — an area flagged by 2+ dimensions independently is high confidence.
  The workflow computes this; do not re-derive it by reading.
- **Contradictions** — architecture says "small change", risk found 15 dependents. One of
  them is wrong. Go and settle it rather than reporting both.
- **Blind spots** — what did no dimension mention? Absence of a finding is not evidence of
  absence, especially in a dimension you folded or skipped. Say which lanes you did not run.
- **Showstoppers** — a single red finding blocks everything and belongs in the first
  paragraph, not on page four.

**Report what you did not cover.** If you skipped security because the type table said to,
write that down. A report that silently omits a dimension reads as "we checked everything".

---

## REPORT FORMAT

Write to `{output_directory}/investigation-{slug}.md`.

```markdown
# Investigation: {Title}

> {date} · {project} · Dimensions run: {list} · Dimensions skipped: {list}
> {N} findings raised, {N} survived refutation

## Executive Summary

**Verdict:** 🟢 GO / 🟡 PROCEED WITH CAUTION / 🔴 STOP

{3–5 sentences. Biggest risk, is it feasible, what's the real effort. Showstoppers first.
Be honest — a report that reads as reassurance is a report nobody needed.}

| | |
|---|---|
| Files affected | {N} |
| New files needed | {N} |
| Complexity | S/M/L/XL |
| Critical risks | {N} |
| Showstoppers | {N} — {list} |

## Confirmed Findings

| Severity | Dimension | Evidence | Finding | Why it survived refutation |
|---|---|---|---|---|
| CRITICAL | security | `src/api/auth.ts:47` | ... | ... |

## Corroborated Areas (flagged by 2+ dimensions independently)
{The highest-signal section. These are where the real problems are.}

## Refuted (raised and killed — recorded so nobody re-raises them)
| Claim | Why it did not hold |
|---|---|

## Per-Dimension Detail
{One short section per dimension actually run. Impact maps, risk matrices, bottleneck
tables, severity lists, feasibility verdict, effort breakdown — whatever that lane produced.}

## Alternatives Considered
| Approach | Pros | Cons | Verdict |
|---|---|---|---|

**Recommended:** {which, and why}

## Not Covered
{Dimensions skipped or folded, and what a reader should not conclude from their absence.}

## Next Step
{`/architect` to plan it · or: resolve these blockers first · or: needs a human decision on X}
```

---

## QUALITY RULES

1. **Evidence over opinion** — every finding cites `path:line` or it does not exist.
2. **Refute before reporting** — a finding nobody attacked is a guess with formatting.
3. **Severity means production impact**, not "I would have written it differently".
4. **Never "can't be done" without what can** — always carry an alternative.
5. **Honest effort** — hidden work is always bigger than it looks. The refactor that has to
   land first is part of the estimate.
6. **Grade confidence** — "confirmed: X" and "suspected: Y" are different claims. Label them.
7. **Reproduce before reporting** — for bugs, verify the issue exists first, and **check
   whether your instrumentation changed the answer.** Observed: a repro installed
   `process.on('uncaughtException')` so the harness would survive to print results, which
   suppressed the default behaviour and turned a *process crash* into what looked like a
   *hung request*. Those need opposite mitigations. Run the failing case once bare, with no
   handlers, no try/catch and no logging you added, before you believe what you measured.
8. **Check git history** — someone may have tried this. Learn from what they hit.
9. **Name what you skipped** — silent omission reads as full coverage.
10. **End with GO / CAUTION / STOP.** The reader needs a decision, not a survey.

---

## CONTEXT DISCIPLINE

This skill reads a lot and that is exactly what degrades a session.

- Run it in a **fresh session**. Do not investigate at the end of a long working session —
  the report is only as good as the attention left. If that is not possible, say so at the
  top of the report and treat the findings as provisional, exactly as `/reviewer` does when
  its independence is compromised. A degraded investigation that hides the fact is worse
  than none, because the next reader trusts it.
- The subagent lanes exist partly to keep their reads out of your window. Let them; do not
  re-read the files they cite unless you are settling a contradiction.
- The report on disk is the durable artifact. Once it is written, the investigation session
  can be closed and `/architect` can start clean from the file.

---

## AFTER INVESTIGATION

1. Executive Summary first — it carries the verdict.
2. Showstoppers must be resolved before anything else.
3. Check Alternatives — there may be a cheaper route.
4. GO or CAUTION → `/architect` to build the plan, feeding it the report path.
5. STOP → resolve the blockers, then re-investigate the parts that changed.

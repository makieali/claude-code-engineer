# Skills

Thirteen skills in four families. Three give Claude Code the world it has to work in, five are
how work gets done in it, two ship something a person outside the team can use, and two keep
a long session from rotting.

```
CONNECT                PIPELINE                                      SESSION
/workspace-init        /investigate → /architect → /executor → /reviewer    /handoff
/server-connect                          ↖___________________↙              /resume-work
/clickup-connect                               /driver
                       /frontend-verify  ← the browser-level counterpart
                       /user-manual      ← ships a PDF to a customer
```

## Frontend — verify what you can't see from a diff

`/frontend-verify` closes the loop UI changes normally skip: capture at three viewports,
read the console, check the accessibility snapshot, fix, re-capture. Up to three rounds.

Given no URL on a feature branch it goes **diff-aware** — but it reports what changed and
where the routing lives rather than mapping files to URLs itself. Hardcoding per-framework
mapping rules is silently wrong for the framework nobody listed: a bad pattern returns an
empty list that reads like "nothing changed". It flags shared components separately, because
a button edit touches every page that renders it and no file-path rule can see that.

**It uses Playwright CLI, not the Playwright MCP.** Same browser, different destination: the
CLI writes screenshots and accessibility trees to disk and the agent reads only what it
needs, where the MCP streams them into context. Playwright's own benchmark puts a typical
task at ~27k tokens via CLI against ~114k via MCP. Use the CLI whenever the agent has a
filesystem — which Claude Code does.

The review criteria live in `references/ux-review.md`, loaded only when a review actually
runs. Console errors first (text, cheap, objective), then layout, then the states nobody
checks — empty, loading, error, long-content — then accessibility, then polish. Polish gets
reported, never silently applied.

## `/user-manual` — a PDF a customer can read

Three passes, and the order is the whole point: **learn** the product from the codebase
(routes are chapters, nav order is reading order, forms are the field tables people actually
look things up in), **capture** every screen by driving the real app, then **write the prose
against the screenshots you got.**

Never the other way round. Prose written before capture describes the UI you imagined, and
every mismatch survives into a document a customer reads.

Output is a paginated PDF with a full-bleed cover, table of contents, figures with captions,
numbered steps, callouts, and field tables. `scripts/` scaffolds the working directory,
drives a config-declared capture plan, and renders the PDF; `assets/manual.css` is the print
stylesheet to restyle per brand; `references/` carries the capture recipe and the paged-media
rules.

Guardrails that matter more than they look: credentials come from the environment and the
capture refuses to run without them, missing screens are reported rather than invented, and
the build names any figure that would render blank and exits non-zero.

## Session — survive a context reset

| Skill | Does |
|---|---|
| `/handoff` | Writes the session record to disk, then tells you whether to `/clear` or `/compact` |
| `/resume-work` | Reads the newest handoff, reconciles it against git, reports where you stand |

Output quality degrades as context grows — well before the window is full, and worst for
information sitting in the middle of a long session. The model summarising at the end is
already impaired by the problem you're trying to escape. So the record gets written
deliberately, while judgment is intact.

**A skill cannot run `/clear` or `/compact`.** Those are REPL commands with no tool behind
them. The loop is: `/handoff` writes → **you** reset → `/resume-work` reads. Any skill
claiming to reset your context for you is guessing.

`/handoff` puts the deterministic parts in `scripts/` so they execute instead of loading:
git state collection, and a path builder that sanitises the title in bash rather than
letting a model interpolate user input into a shell command.

## Connect — give the agent the world

| Skill | Does |
|---|---|
| `/workspace-init` | Lays out a multi-repo workspace and writes the root `CLAUDE.md` map by reading each repo |
| `/server-connect` | Non-interactive SSH access, then writes `server-info/` by interrogating the machine |
| `/clickup-connect` | Connects the task board and has Claude write its own workspace reference, gotchas included |

These share one idea, and it is the reason they are skills instead of documentation:
**they discover, then write their own notes.** Nothing here is a template you fill in. The
agent connects, looks, and produces the reference file that every later session reads. A
quirk found once gets written where it is found for free, and the next session inherits it.

That also means none of your real infrastructure is ever in this repo. The procedure is
public; your hosts, tokens, and workspace IDs are generated locally into gitignored folders.

## Pipeline — do the work

| Skill | Owns | Writes |
|---|---|---|
| `/investigate` | Is this feasible? What breaks? What's it really cost? | `investigation-{slug}.md` |
| `/architect` | Phases, tasks, shared contracts, isolation, rollback | `plan.md`, `progress.json` |
| `/executor` | One task at a time, verified externally, committed | `state/phase-N.json` |
| `/reviewer` | Fresh-context validation gated on real exit codes | `state/phase-N.review.json` |
| `/driver` | What happens next — advisory, or autonomous behind guardrails | nothing |
| `/decision-log` | Durable decisions with their reasoning; searched before a settled question reopens | `docs/decisions/D-NNN-*.md` |

## Install

Install as a plugin:

```
/plugin marketplace add makieali/claude-code-engineer
/plugin install claude-code-engineer@claude-code-engineer
```

Or by hand:

```bash
git clone https://github.com/makieali/claude-code-engineer
cp -R claude-code-engineer/skills/* ~/.claude/skills/
rm -f ~/.claude/skills/README.md    # the skills index, not a skill
```

Per-project instead of globally: copy into `.claude/skills/` in the project root.

Each skill is a self-contained `SKILL.md`. Take one, take all thirteen — they work individually
and compose better together.

## Before you use them: set your model mapping

Most skills carry a **Model routing** table naming roles — *orchestrator*, *executor*,
*bulk*, *advisor* — and a dated line mapping them to real models. That mapping is mine, as
of the date on it. **Replace it with yours.**

Roles are named rather than models because model names are the fastest-decaying content in
this discipline. Whatever you map them to, set the model **explicitly** on every spawn —
omitting it inherits the orchestrator's rate, which is how six mechanical lanes quietly get
billed as six orchestrators. Check whether your cheapest tier supports an effort parameter
at all; several don't.

Skills with no meaningful fan-out don't carry a routing table. A table in every file would
be exactly the bloat that makes real instructions get dropped.

## What these do differently

**Nothing verifies itself.** The executor proves each task with a command that can fail. The
reviewer runs in a fresh context on the diff, not the conversation, and its verdict is gated
on recorded exit codes from test, lint and build — a non-zero exit forces
`changes_required` no matter how good the code looks. A model cannot be its own referee.

**Findings get attacked before they're reported.** `/investigate` and `/reviewer` both run a
refutation pass: every finding faces an agent trying to kill it, and on load-bearing changes
it faces three, each from a different angle. Findings that die are recorded as
raised-and-refuted so nobody re-raises them next cycle.

**Finding and filtering are separate passes.** Reviews are never asked for "only
high-severity issues" — current models comply literally and report less. Everything is
reported unfiltered, then a separate pass assigns severity. The finder never grades itself.

**Fan-out is scaled to the question.** `/investigate` doesn't spawn six agents by reflex; it
selects dimensions by what's load-bearing and folds the rest into one lane. Spawn count is a
cost, not a quality signal.

**Parallel phases are structurally safe.** One state file per phase with exactly one writer,
and `parallel_safe` phases run in their own git worktree. Shared mutable state is a
lost-update race that no amount of careful instruction fixes — so there isn't any.

**Failure stops rather than compounds.** A failed task whose `blocks` list is non-empty halts
the phase instead of letting later tasks build on ground that isn't there.

**Secrets are structurally absent, not carefully avoided.** `/server-connect` and
`/clickup-connect` gitignore the target before writing to it, record that an env var exists
without its value, and verify the ignore rule before any commit.

**Sessions end deliberately.** The executor writes a real handoff — including *Ruled out*,
the section automatic summaries reliably lose and the reason a fresh session re-tries
everything that already failed.

## Scripts report observations. Agents draw conclusions.

The line between "put this in a script" and "write this as guidance" is not code volume. It
is whether the next step depends on what the last step found.

**A script is right when the sequence never changes** — sanitising a filename, rendering a
PDF, collecting git state, driving a browser through fixed viewports. These have one correct
order and no judgment in them.

**Guidance is right when the finding determines the next move** — interrogating an unknown
server, exploring an unfamiliar codebase. A script there encodes a guess about what the
world looks like, then reports confidently on a world that does not match it.

Both failures were measured in this repo, not theorised:

- A server probe checked `/etc/nginx`, `/etc/caddy` and `/etc/apache2`, found nothing, and
  reported **no web layer** on a host serving 80 and 443 — the proxy was a container. The
  contradicting evidence was three lines up in its own output. A script cannot notice a
  contradiction in its own results. That script was deleted, not patched.
- A dev-server check reported `ALREADY_RUNNING` in an empty directory, because macOS
  ControlCenter answers on `:5000`. It now prints `:5000 HTTP 403 Server: AirTunes/950.7.1`
  and says nothing about whether that is your app.

That second fix is the general rule: where a script must touch an unknown environment, have
it **report the evidence and stop.** `ALREADY_RUNNING` is a conclusion and can be wrong;
`HTTP 403, Server: AirTunes` is a fact and cannot be. The agent reading it has strictly more
information than the agent reading the verdict.

This is also Anthropic's own framing — scripts are the *low-freedom* tool for fragile,
fixed-sequence work, and adaptive exploration is the *high-freedom* case.

## Tested

`tests/run.sh` is a regression suite. Every case guards a defect that was found by *running*
these skills against real repositories — not one was found by reading them. If a case fails,
that specific bug has come back.

It covers shell-injection in handoff titles, the default-branch history gap, frontmatter
parsing, route reporting, dev-server observation-vs-verdict, and a staleness check that fails
when a model routing table ages past 90 days — because a repo promising *maintained* should
break its own build rather than quietly rot.

The suite is mutation-tested: reintroducing each original bug makes the matching case fail.
A green suite that cannot fail is decoration.

## Progressive disclosure

Only the frontmatter of each skill is loaded into a session. The body loads when the skill
triggers, and bundled files load only when the task reaches them — so anything needed for
one mode shouldn't sit in the body taxing every invocation.

Applied here: workflow scripts, plan templates, review criteria, print CSS and server probes
live in `references/`, `assets/` and `scripts/` beside each skill. Scripts execute without
loading at all — only their output costs tokens.

The largest `SKILL.md` here is 295 lines against Anthropic's 500-line guidance, and most are
well under. That is not incidental: these were prose-heavy first drafts, and cutting them
back was the single biggest quality change made to them.

`/investigate`, `/executor`, `/reviewer` and `/driver` each carry a ready-to-run workflow
script in `references/`, for when control flow should be deterministic rather than
model-decided: fan out over a known list, verify each result, loop until a proven condition.

Worth reading even if you never run them, because the structure is the argument —
schema-forced outputs mean cross-analysis is plain code instead of a model re-reading six
reports and guessing where they agree.

## When not to use any of this

Orchestration overhead only pays on long-horizon work with real contracts between phases.
For a single-file fix, skip the pipeline entirely — `/architect` on a one-line change
produces a plan longer than the change. The connect skills are the opposite: one-time setup,
and everything afterwards is cheaper.

## Maintenance

The pipeline skills were written in February 2026 and rewritten in July, because the model
behaviour they were built against moved — they had picked up self-verification habits,
unconditional six-way fan-out, and a delegation profile that no longer matched what the
models do by default. See [`../CHANGELOG.md`](../CHANGELOG.md).

Same rule as the instruction file next door: treat them as code, review them when you
upgrade, and delete what stops being true.

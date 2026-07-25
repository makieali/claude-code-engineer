# Changelog

Every entry records what changed, why, and against which source. Dates are when the claim
was verified, not when the model shipped.

---

## 2026-07-26

### The pipeline was run end to end on a real repository

Until now the skills were reviewed, not exercised. `/architect`, `/executor` and `/reviewer`
were run for real against [`sindresorhus/yocto-queue`](https://github.com/sindresorhus/yocto-queue)
— clone, plan, three phases, two of them concurrent in git worktrees, review, merge — adding
`peekLast()` with types, tests, and docs. Result: 8 tests green, `tsd` green, 50 lines across
5 files, feature works.

Five defects surfaced. Every one required running the thing.

- **The executor recorded success for work that never happened.** Phase 3 committed
  `"status": "needs_review"` with `"exit_code": 0` while `readme.md` contained zero mentions
  of the new method, and the recorded commit sha pointed at the previous HEAD because there
  was nothing to commit. State files are self-reported and nothing validates them. Documented
  in `/executor`, and it is the concrete reason `/reviewer` re-runs every command itself.

- **A `verify_command` that could never pass.** The plan specified
  `grep -q '### peekLast()'` against a readme using `` #### `.peek()` `` — four hashes,
  backticks, leading dot. The architect wrote a check without reading the file it targets.
  `/architect` now requires verify commands be checked against the real file.

- **The plan blocked the executor on step one.** `/architect` writes `plans/` and never
  committed it; `/executor` requires a clean tree. Added the commit step.

- **Worktree placement is load-bearing and was undocumented.** Dependencies are gitignored,
  so they do not follow a worktree. Nested at `.worktrees/phase-N`, tooling walks up and
  finds the parent's `node_modules` and verification works. Placed outside the repo, every
  verify command dies with "Cannot find package". Measured both ways.

- **Reviewer independence cannot always be satisfied.** The review ran in the session that
  wrote the code, which the skill's own first line forbids. `/reviewer` now defines what to
  do when a fresh session is unavailable: run only the objective half, record
  `reviewer_independence: VIOLATED`, mark the verdict provisional.

### Corrected

- **The state-race rationale was imprecise.** It claimed "the second write silently erases
  the first". Measured: two processes doing read-modify-write on one JSON file, 60 updates
  each, **both crash on `JSONDecodeError` and leave the file invalid** — a torn write, worse
  than a lost update. And the case it *doesn't* cover: two executors on separate git branches
  editing the same file on different lines merge cleanly. So the danger is concurrent writes
  to one path, not the merge, and the fix needs both halves — one writer per file *and* one
  working tree per phase. `/architect` now says exactly that.

### Verified working

Contract-first decomposition, per-phase branch and worktree isolation, single-writer state
(reviewer never touched the executor's file), `blocks`-driven stop-on-failure, and the
mutation check — which caught all three deliberate breakages of the new implementation and
both breakages of the type declaration.

### Added a regression suite, and made two promises structural

**`tests/run.sh`** — 23 assertions across 6 cases, every one guarding a defect found by
*running* these skills against real repositories. Until now each fix was protected only by
my memory of having made it, which is the least durable thing in the repo.

The suite is **mutation-tested**: reintroducing each original bug makes the matching case
fail. Removing the handoff-title allowlist fails 5 assertions; restoring the `BASE..HEAD`
history bug fails the default-branch case. A green suite that cannot fail is decoration.

Two bugs were found while building it, both in the harness rather than the skills:

- `d=$(mktestrepo)` ran its `cd` in a subshell, so the cases silently executed **inside this
  repo** — creating `plans/` and a stray branch in the tree under test. Replaced with
  `enter_testrepo`, which cds in the caller and refuses to run outside a temp directory.
- The staleness check used `date -j -f '%Y-%m-%d'`, which on BSD **exits 0 and returns the
  current epoch**, making every date look zero days old. A third instance of the same
  pattern: a command that succeeds while producing a wrong answer.

**Staleness is now enforced, not requested.** A case fails when any model routing table
ages past 90 days. A repo named *maintained* should break its own build rather than quietly
rot — verified against a 2025-dated fixture.

**Fresh review context is now structural.** `/reviewer` and `/investigate` spawn their
passes as subagents, which start empty by construction. That converts "please start a new
session" from a discipline into a property, and it is the direct fix for the independence
violation recorded earlier in this changelog.

### Added — `/decision-log`

`Ruled out` promoted from per-session to permanent. A handoff's rejected approaches die with
the handoff; this is searched *before* a settled question reopens, so reversing a decision is
deliberate rather than accidental. Append-only, superseding is a new file plus a pointer, and
every entry carries a **revisit condition** — a decision nobody dares change is as expensive
as one nobody recorded.

### Added — a worked example

[`docs/example-run.md`](docs/example-run.md): the pipeline applied end to end to
`sindresorhus/yocto-queue`, with the five defects it exposed recorded rather than tidied
away. For a stranger deciding whether any of this is real, one honest run beats any amount
of prose about external verification.

### Removed the hardcoded lists — the agent already knows how to look

Same principle one level up: a skill should not enumerate what Claude Code can see for
itself. Every fixed list is a guess that is silently wrong for the case nobody listed, and
wrong in the worst way — an empty result reads like "nothing here" rather than like a miss.

- **Manifest lists** in `/architect` and `/investigate` enumerated fifteen filenames to
  identify a stack. Replaced with `ls -a` and *"you know what a manifest looks like; look."*
  The old list had no `deno.json`, `bun.lockb`, `build.zig`, `rebar.config` or
  `dune-project`, and would have reported "no manifest" on any of them.

- **Port list** in `dev-server.sh` probed eleven guessed ports. It now asks the OS what is
  actually listening (`lsof -iTCP -sTCP:LISTEN`) and falls back to the common suspects only
  if that fails. It finds whatever port the project chose, including ones no list contains.

- **Route mapping** in `changed-routes.sh` encoded per-framework `sed` rules for Next
  app-router and pages-router, SvelteKit, Nuxt, Astro and Remix. Deleted. It now reports
  which files changed and where the project declares its routing, and stops — the agent
  reads the real router config and maps it. Verified against a Next app-router tree with
  zero Next-specific code in the script.

Two fixed lists survive, deliberately, because neither is a guess about the environment:
the capture viewports (a choice of breakpoints, overridable by env var, detecting nothing)
and the two known binary names for the Playwright CLI package.

### Audited every remaining script against the same test

After deleting the server probe, the other nine scripts were checked against the rule that
killed it: **does this draw a conclusion about an unknown environment?** Eight report facts
and were left alone — sanitising a path, rendering a PDF, collecting git state, driving a
browser through fixed viewports. None of those have a step that depends on a finding.

One failed. `dev-server.sh` printed `ALREADY_RUNNING` — a verdict, and one it had already
got wrong when macOS ControlCenter answered on `:5000` in an empty directory. The earlier
fix taught it to sniff for HTML, which is the same treadmill: a script guessing better
rather than an agent looking.

It now reports evidence and stops:

```
:5000  HTTP 403  title=—   Server: AirTunes/950.7.1
```

AirPlay is obvious at a glance, no conclusion was drawn, and the agent has strictly more
information than it had from `ALREADY_RUNNING`. The general rule, now stated in
`skills/README.md`: **where a script must touch an unknown environment, have it report the
evidence and stop.** A verdict can be wrong; `HTTP 403, Server: AirTunes` cannot.

### Removed — the server probe script, and the reasoning for it

`/server-connect` was run against a real Ubuntu 24.04 host. The access half worked exactly
as designed: `BatchMode` verification passed, `sudo -n` was correctly reported, and the env
scan printed **names only** — database passwords, cloud API keys and ingest tokens all
listed by name with zero values emitted. That was the guarantee that had to hold on a real
host holding real secrets, and it held.

The interrogation half was wrong in a way that mattered. `probe-server.sh` reported an empty
**web layer** on a host actively serving 80 and 443, because it checked host paths for
nginx, caddy and apache and the reverse proxy was a container. The contradicting evidence —
`docker-proxy` bound to both ports — was three lines up in the script's own output.

**A script cannot notice a contradiction in its own results. An agent can.** So the script
is gone, replaced by guidance that carries the reasoning rather than a command list: *ports
served but no web server installed means the proxy is containerised — go look at `docker ps`
and find the compose file, because on that kind of host the compose file is the deployment
unit.*

This is not a reversal of the earlier move toward `scripts/`. It is the distinction
Anthropic's own guidance draws: **scripts are the low-freedom tool** for fragile,
fixed-sequence operations, and adaptive exploration is the high-freedom case. Path
sanitisation, PDF rendering and git state collection stay scripts because their steps never
depend on what the previous step found. Interrogating an unknown server is the opposite —
that is the whole job.

### /frontend-verify run against a real browser — the capture path was broken

`capture.sh` had never touched the actual Playwright CLI; it was written against
documentation. Run against a live page with planted defects, it failed in three ways, and
the third is the worst kind of failure this repo exists to argue against.

- **`goto` does not start a browser.** A bare `goto` fails with `The browser 'default' is
  not open`. The docs list `open [url]` and `goto <url>` side by side as navigation
  commands; only one of them is self-starting. `capture.sh` now calls `open` once and traps
  EXIT to `close`.

- **Two commands did not exist.** `run-code` is `eval`. `--full-page` is a flag, not a
  positional. Written from a documentation summary rather than `--help`.

- **`--filename` is resolved against the CLI's browser process, not your shell** — so a
  relative path writes somewhere unreachable **and exits 0.** Combined with the previous
  point, the script printed `shot 375w -> …png` three times for three screenshots that did
  not exist anywhere on disk.

That last one is the executor's false-state-file bug in a different costume: **exit 0 means
the command ran, not that the artefact exists.** `capture.sh` now uses absolute paths and
tests `[ -s "$SHOT" ]`, printing the byte count. It is the second time in this repo that
trusting a status code produced a confident report of work that never happened.

Also added: the snapshot check counted new `.yml` files, which false-negatives when a page
is unchanged and deduplicated. It now reports the newest non-empty snapshot and greps it for
unnamed interactive elements.

Verified against `@playwright/cli` 0.1.17: three real screenshots (13–15KB), both planted
console errors caught, and the accessibility snapshot exposed both planted a11y defects —
an unnamed `button [ref=e4]`, and an alt-less image absent from the tree entirely.
`references/setup.md` now carries the real command surface and all three traps.

### /workspace-init and the handoff round trip exercised

`/workspace-init` run against a real three-repo, three-stack workspace (Node, Python, Go);
`/handoff` → `/resume-work` run as an actual round trip. Three more defects.

- **The gitignore check false-alarmed, and its implied fix was dangerous.** The skill says a
  workspace parent is "usually not a git repo", then verified with `git check-ignore`, which
  always fails outside one. A user following it verbatim is told their ignore rules are
  broken when nothing is even trackable — and the obvious remedy is `git init`, the single
  action that could put `server-info/` under version control. Now branches on whether the
  parent is a repo, and says explicitly not to init one.

- **The root-map template assumed a deployed service topology.** Services, ports, "How they
  talk", Environments — none apply to a workspace of libraries. Filling them in means
  inventing an architecture, which is the exact failure the map exists to prevent. The skill
  now says to omit inapplicable sections and record that they were omitted.

- **`gather-state.sh` recorded no history when run on the default branch.** It listed commits
  as `BASE..HEAD`, which is empty when `HEAD` *is* the base — so a handoff written on `main`,
  the common case at the end of a piece of work, captured nothing. Falls back to recent
  history and says why.

Verified working: cross-stack survey (three manifests, three command sets), the
mark-as-unverified discipline (Go commands executed and ticked, Python left explicitly
unverified when its collection failed), safe-path sanitisation, and the handoff round trip —
`/resume-work` located the file, matched the branch, and reported commits-since and age.

### /investigate exercised on a real codebase

Run against `expressjs/express` 5.2.1 with a real question: does a class of unhandled
rejection silently hang a request? It does — and the run validated the two mechanisms the
skill is built on.

**Dimension selection worked as designed.** A bug investigation spawned two lanes
(architecture, risk), folded performance into one, and skipped effort and feasibility —
then named the skipped ones in the report, so absence is not read as coverage.

**The refutation pass killed a finding the investigation itself manufactured.** The first
reproduction reported "a throw inside `setTimeout` hangs the request". Refuting it showed the
opposite: the repro had installed `process.on('uncaughtException')` so the harness would
survive to print results, and that handler suppressed the real behaviour — the process
*crashes*. Hang and crash need opposite mitigations. Without the refutation pass the report
would have shipped the wrong fix.

Added to `/investigate` as a result:

- **Instrumentation bias**, folded into quality rule 7. Reproducing is not enough; run the
  failing case once bare, with no handlers, no try/catch and no added logging, before
  believing the measurement.
- **A degraded-session protocol** matching `/reviewer`'s. The skill says to investigate in a
  fresh session; it now says what to do when that is impossible — declare it at the top and
  mark the findings provisional, rather than producing a quietly degraded report.

### Fixed — the driver deadlocked on approved phases

`/driver` was run for real against the plan produced by the end-to-end test, and rule 4
matched an already-approved phase forever.

Cause: the single-writer rule is correct, and it has a consequence nobody traced. The
executor writes `needs_review` into `phase-N.json` and stops. The reviewer may only write
`phase-N.review.json`. **Nothing is permitted to move `phase-N.json` out of
`needs_review`** — so a driver reading the executor's field alone sees an approved phase as
unreviewed and sends it back to review on every invocation, indefinitely.

Fix: effective status is a **join** of the two files, defined explicitly in `/driver`. The
review file wins on the review dimension because its writer is the only one allowed to
judge. `needs_review` now reads as *"review requested"*, not as a status.

Corrected in three places that all stated it wrongly:

- `/driver` — the join table, and rules 4, 6 and 7 rewritten to use effective status
- `/executor` — said "the reviewer sets `done`". It cannot; `done` is derived. An executor
  phase legitimately ends at `needs_review` and stays there
- `/architect` — `needs_fixes` and `done` removed from the writable status values

Verified after the fix: phase 1 derives to `done`, phases 2 and 3 report `needs_review`,
next action resolves to `/reviewer` on phase 2, and phases 2 and 3 are correctly offered as
parallel. It advances instead of looping.

### Progressive disclosure applied to the skills

The skills were written prose-heavy, with workflow scripts and templates inline. Every one
was under the 500-line guidance, so they passed the letter of it and missed the point:
Anthropic's actual test is *"does this paragraph justify its token cost?"*, and a workflow
script needed once in ten invocations was being loaded on all ten.

Moved into `references/` and `scripts/`, which cost nothing until read:

| Skill | Before | After | Moved |
|---|---|---|---|
| `/reviewer` | 400 | 295 | workflow script |
| `/architect` | 376 | 244 | plan + phase templates, judge-panel |
| `/investigate` | 353 | 269 | workflow script |
| `/executor` | 322 | 265 | workflow script |
| `/server-connect` | 275 | 241 | server interrogation → `scripts/probe-server.sh` |
| `/driver` | 229 | 152 | autonomous workflow |

Nothing was deleted — each pointer gained a short explanation of *why* the mode exists, so
the total content grew slightly while the always-loaded portion shrank by a third.

`/server-connect` is the clearest case: ~45 lines of discovery bash were pasted into context
on every run. As `scripts/probe-server.sh` it executes and only its output costs tokens.

---

## 2026-07-25

Seven changes on one day: the repo went from a single instruction file to an
instruction file plus twelve skills. Listed newest first.

### User manuals

#### Added

- **`/user-manual`** — builds a print-quality PDF manual: reads the codebase to learn the
  product, drives the real UI with Playwright to capture every screen, then writes the prose
  against what was captured. Ships `scripts/` (scaffold, config-driven capture, PDF render),
  `assets/manual.css` (the print stylesheet), and `references/` for the capture recipe and
  paged-media rules.

  **Capture before prose, always.** Text written first describes an imagined UI, and every
  mismatch survives into a document a customer reads. Missing screens are listed as not
  covered; they are never invented.

- **Credentials are environment-only and enforced.** The capture exits if auth is configured
  and `MANUAL_EMAIL` / `MANUAL_PASSWORD` are unset, rather than silently capturing thirty
  screenshots of a login redirect.

- **Three print settings that are invisible until they're missing** — `printBackground`,
  `print-color-adjust: exact`, `preferCSSPageSize`. Without them the PDF prints white, or
  ignores `@page` margins. Documented with the failure each one causes.

#### Fixed

Both bugs below were found by building a real PDF from a live page, not by reading the code.
Both were inherited from a working implementation where they had never fired.

- **The image-decode wait deadlocked on a broken image.** It gated on
  `img.complete && img.naturalWidth > 0`, treating a 404'd image as still loading — but a
  404'd image is already `complete` with `naturalWidth: 0`, and its `error` event fired
  before the handler attached. The build hung forever with no output. Now gates on
  `complete` alone and races every wait against a timeout. This is precisely the check that
  exists to catch blank figures, and it was the thing that hung.

- **`waitUntil: 'networkidle'` on the HTML load.** Never settles when a resource 404s. Now
  `'load'` with an explicit timeout — the decode wait is the stronger guarantee anyway, so
  networkidle bought nothing and cost the failure mode the script exists to detect.

### Frontend verification

#### Added

- **`/frontend-verify`** — capture at three viewports, read the console, check the
  accessibility snapshot, fix, re-capture. Up to three rounds, then stop and say the problem
  isn't the CSS. A UI change that passed unit tests and was never opened in a browser is
  unverified; this is the browser-level counterpart to `/reviewer`.

- **Playwright CLI over Playwright MCP.** Both drive a real browser; the difference is where
  output goes. The CLI writes screenshots and accessibility trees to disk and the agent reads
  only what it needs. The MCP streams them into context. Playwright's own benchmark: ~27k
  tokens via CLI against ~114k via MCP on a typical task. The rule generalises — **CLI beats
  MCP whenever the agent has filesystem access**, which is also why `gh` is the right GitHub
  interface and a GitHub MCP is not.
  *Source: microsoft/playwright-cli and playwright.dev/agent-cli, verified 2026-07-25. The
  CLI shipped early 2026 and its flags are still moving.*

- **Diff-aware scoping.** No URL on a feature branch maps changed files to candidate routes
  across Next app-router and pages-router, SvelteKit, Nuxt, Astro, and Remix. Shared
  components are reported separately rather than folded in, because a button edit touches
  every page that renders it and file-path mapping is blind to that. Output is a suggestion
  requiring confirmation — a clean report on routes nobody touched is worse than no report.
  *Pattern adapted from [gstack](https://github.com/garrytan/gstack)'s `/design-review`.*

- **Review criteria in `references/`, not in the skill body.** Console first (text, cheap,
  objective), then layout, then the states that actually break — empty, loading, error,
  long-content, single-item — then accessibility, then polish. Loaded only when a review
  runs. Finding and severity stay separate passes, same as `/reviewer`.

- **Blocking issues get fixed; polish gets reported.** Taste is the user's call.

#### Fixed

- `changed-routes.sh` used `|` as both the `sed` delimiter and the alternation operator, so
  every route pattern failed to parse. Caught by testing against real Next, SvelteKit, and
  pages-router trees rather than by reading it.

### Session handoff

#### Added

- **`/handoff` and `/resume-work`** — write session state to disk before a context reset,
  read it back after. Two skills, not one: they run either side of a `/clear` and share no
  state beyond the file.

  **A skill cannot invoke `/clear` or `/compact`.** They are REPL commands with no tool
  behind them, so the honest loop is write → human resets → read. Documented rather than
  worked around. Which reset to run is a judgment the skill makes and explains: compact when
  the thread still matters, clear when it doesn't, and always clear rather than compacting
  twice — a summary of a summary is where detail goes to die.

- **Deterministic parts moved to `scripts/`.** Git state collection and path construction
  execute rather than loading into context. This is the progressive-disclosure pattern
  applied properly: bundled files cost nothing until read, and scripts cost only their
  output. *Source: Anthropic, "Skill authoring best practices," platform.claude.com,
  verified 2026-07-25.*

- **Title sanitisation happens in bash, not in the prompt.** A handoff title is user input;
  building the path model-side means interpolating untrusted text into a shell command.
  `handoff-path.sh` applies an allowlist (`a-z 0-9 . -`) and prints the path for verbatim
  use. Tested against `evil; rm -rf /`, `$(whoami)`, and path traversal. *Engineering, not a
  model-behaviour claim.*

- **Handoffs are append-only**, timestamped, and carry their branch in frontmatter. Filename
  order is chronological order, which survives copies and checkouts where mtime does not.
  Nothing overwrites a handoff — the sequence is the record. *Pattern adapted from
  [gstack](https://github.com/garrytan/gstack)'s `context-save`.*

- **`/resume-work` reconciles the record against reality** before trusting it — branch,
  commits since, dirty files — and reports the handoff's age. A handoff from three weeks ago
  on a branch with twenty new commits is archaeology, not state. It surfaces `Ruled out`
  *before* proposing anything, since reading it afterwards defeats the point.

### Connect skills

#### Added

- **`/workspace-init`, `/server-connect`, `/clickup-connect`** — the setup layer, shipped as
  skills rather than as documentation folders.

  The distinction is the whole design. A folder of READMEs makes the *human* do the setup
  from a template. These make the agent do it by **discovery**: `/server-connect` opens a
  connection and interrogates the machine — services, ports, unit files, deploy paths, log
  locations — then writes `server-info/` from what it found. `/clickup-connect` walks the
  API and writes its own workspace reference. `/workspace-init` reads every sibling repo's
  manifest and generates the root `CLAUDE.md` map.

  Second-order effect worth stating: **this removes the sanitisation problem instead of
  managing it.** A template repo has to carry example hosts and IDs that look real enough to
  be useful, which is exactly how a real one eventually gets committed. Here the repo carries
  only the procedure, and every user's hosts, tokens, and workspace IDs are generated locally
  into folders that are gitignored before they are written to. There is nothing to scrub
  because nothing real is ever present.

- **Secret handling is structural, not procedural.** Both connect skills add the ignore rule
  and verify it with `git check-ignore` *before* writing anything, record that an env var
  exists without recording its value, and treat anything already committed as exposed rather
  than removable.

- **Passphrase-free SSH keys, with the tradeoff written down.** An agent cannot answer an
  interactive passphrase prompt — it hangs, or reports a connection failure that is actually
  an invisible prompt, and every unattended path breaks the same way. The skill states this
  plainly and buys the protection back structurally: one key per server per project, never a
  personal key, dedicated user, revocable, `chmod 600`. *Operational guidance, not a
  model-behaviour claim.*

### Skills pipeline, and workflow guidance

Repo renamed from `claude-md-maintained` to `claude-code-engineer`. The instruction file is
one layer of a setup, not the whole product, and the name said otherwise. The old URL
redirects; install commands now use `curl -L` so a future rename can't break them.

#### Added

- **`skills/`** — the five-skill plan/execute/review pipeline: `/investigate`, `/architect`,
  `/executor`, `/reviewer`, `/driver`. Written February 2026, rewritten now against the same
  amendments in §5–§8 of `CLAUDE.md`, which they predated and in several places contradicted.
  What changed and why is in [`skills/README.md`](skills/README.md); the short version:

  - Reviews were grading their own findings in the same pass. Split into find → refute →
    filter, so the finder never assigns severity to its own work. *Same source as §6.*
  - `/investigate` spawned six subagents unconditionally, including on questions where its
    own weighting table rated a dimension at 5%. Fan-out is now selected by what's
    load-bearing for the question asked. *Same source as §6's delegation cap.*
  - No skill named a model or an effort level, so every mechanical lane inherited
    orchestrator rates. Each skill now carries a routing table by role. *Same source as §7.*
  - Verdicts were checkbox-based. They are now gated on recorded exit codes from test, lint
    and build — a non-zero exit forces `changes_required`. *Applies §5: a self-graded
    checklist cannot fail honestly.*
  - Session-end handling wrote a one-line note. It now writes the §8 handoff, `Ruled out`
    included.

- **§6 — subagent, workflow, or neither.** A third option exists now, and picking wrong is
  expensive in both directions. Deterministic control flow in a workflow is also what makes
  a stop condition provable rather than asserted, which is §5 applied to orchestration.
  *Structural guidance, not a model-behaviour claim — no vendor source, and none implied.*

- **§6 — one writer per file for parallel agents.** Two agents doing read-modify-write on
  shared state silently lose one of the writes. Found in the skills' own `progress.json`,
  which `/architect` marked `parallel_safe` and `/executor` told several agents to update
  concurrently. Fixed structurally: per-phase state files with a single writer each, and
  git worktrees for agents touching the same tree. *Engineering defect found in this repo's
  own tooling, not a vendor claim.*

- **Preamble** — `workflow` added to the hook / skill / subagent ladder for what does *not*
  belong in an always-on instruction file.

### Composition guidance

#### Added

- **§7 composition pattern.** Added guidance to compose a strong orchestrator with cheaper
  capable executors and an on-demand advisor, rather than defaulting every task to the
  largest model. Kept deliberately model-agnostic — named model tiers decay faster than
  anything else in an agent instruction file, and most readers don't share one lineup or
  budget. The pattern (orchestrator / executor / advisor, escalate the model not the
  effort) is what's durable; which model fills each role is the reader's to map.

### Initial release

Forked from the four-principle file and amended for current frontier model behaviour.
Sections 1–4 unchanged.

#### Added

- **§5 Verification is external, never self.** Explicit self-verification instructions
  ("double-check your answer," "use a subagent to verify") now compound with behaviour the
  model already has, costing tokens without improving results. Replaced with guidance to
  build external checks — test suites, build gates, evaluator models, reviewers in fresh
  contexts.
  *Source: Anthropic, "Prompting Claude Opus 5," platform.claude.com, verified 2026-07-25.*

- **§6 Cap delegation, hold scope.** Current models delegate more readily than earlier
  ones, which is valuable on genuinely independent work and wasteful on small tasks. Added
  explicit delegation limits and scope-holding language.
  *Same source.*

- **§6 Reviewer instruction warning.** Asking a reviewer to "only report high-severity
  issues" or "be conservative" causes it to follow the instruction literally and report
  less. Corrected guidance: ask for everything, filter in a separate pass.
  *Same source.*

- **§7 Model and effort.** Effort is now a primary cost lever alongside model choice. Added
  the escalate-the-model-not-the-effort heuristic, the warning that effort settings do not
  carry across model generations, and the note that changing effort mid-session invalidates
  prompt caching.
  *Source: Anthropic, "Effort," platform.claude.com, verified 2026-07-25.*

- **§8 Context discipline** and the handoff template. Output quality degrades measurably as
  input length grows, beginning well before the context window is full, and worst for
  information positioned mid-context.
  *Sources: Chroma Research, "Context Rot: How Increasing Input Tokens Impacts LLM
  Performance," 2025 (18 models tested). Liu et al., "Lost in the Middle," TACL 2024.
  Anthropic, "Effective context engineering for AI agents," 2025.*

#### Changed

- **§4 Goal-driven execution.** "Loop until verified" now reads "loop until *externally*
  verified," with a pointer to §5. The original wording predates models that self-verify by
  default.

- **§1 Think before coding.** Added a bias note: check in only when different readings
  would produce materially different work. The original biases toward caution over speed,
  which was correct for agents that under-asked and is now over-cautious on trivial tasks.

#### Notes

- Attribution corrected throughout. The upstream file is widely credited directly to Andrej
  Karpathy; it was written by Forrest Chang, derived from Karpathy's observations, and has
  not been endorsed by him.
- Deliberately excluded: the ten-rule variant circulating under Karpathy's name. Provenance
  disputed.

---

## Pending review

Items to check on the next frontier model release:

- [ ] Whether §5's self-verification guidance still holds, or reverses again
- [ ] Effort ladder availability per model — currently not all models support the parameter
- [ ] Whether delegation caps are still needed or become default behaviour
- [ ] Pricing references in any derived material — these move fast and go stale quietly

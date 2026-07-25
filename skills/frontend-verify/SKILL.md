---
name: frontend-verify
description: >
  Verifies frontend changes in a real browser — screenshots at multiple
  viewports, console errors, accessibility snapshot — then fixes what it
  finds and re-verifies. Scopes to routes touched by the current diff when
  no URL is given. Use after changing UI code, before shipping a frontend
  change, when a page "looks wrong", or when asked whether something
  actually works in the browser.
  Trigger: "check the UI", "does this look right", "screenshot the page",
  "verify the frontend", "review the design", "test it in the browser".
---

# Frontend Verify — Look At It, Then Fix It

A frontend change that passed unit tests and was never opened in a browser is unverified.
This closes that loop: **capture → review → fix → re-capture** until clean.

**Use the CLI, not the MCP.** Playwright CLI writes screenshots and accessibility snapshots
to disk and lets you read only what you need. The MCP streams them into context — roughly
4× the tokens for the same task. Claude Code has filesystem access, so the CLI is the right
tool. See `references/setup.md` if it isn't installed.

## Step 1: Scope

**URL given?** Use it.

**No URL, on a feature branch?** Diff-aware mode:

```bash
~/.claude/skills/frontend-verify/scripts/changed-routes.sh
```

It reports what changed and where this project keeps its routing — **it does not map files
to URLs.** That mapping is framework-specific, and a hardcoded ruleset is silently wrong for
the framework nobody listed: a bad pattern yields an empty list that reads like "nothing
changed". Read the routing config it points at and map it yourself.

If shared code changed, route mapping cannot see its reach — a button edit touches every
page that renders it. Pick the highest-traffic routes that use it and say that is what you
covered.

Confirm the list before capturing. Wrong routes means a clean report on pages nobody
touched, which is worse than no report.

**No URL, on the default branch?** Ask which page. Do not guess.

## Step 2: Get the app running

```bash
~/.claude/skills/frontend-verify/scripts/dev-server.sh
```

It reports what is listening and what this project says starts it — **it does not decide
whether your app is up.** Match the page title against the project you are in. A port
answering is not your app: on macOS, ControlCenter holds `:5000` and `:7000` and returns
403 with no HTML.

Already running? Reuse it. Never start a second instance on another port and review that.

**Authenticated pages:** attach to your real, already-logged-in browser rather than a fresh
context — `playwright-cli attach --extension`. A fresh browser hits the login wall and you
end up reviewing a redirect. Details in `references/setup.md`.

## Step 3: Capture

```bash
~/.claude/skills/frontend-verify/scripts/capture.sh <url> [<url> ...]
```

Per URL it writes, under `.playwright-cli/`:

- screenshots at **375** (mobile), **768** (tablet), **1440** (desktop)
- the accessibility snapshot (YAML)
- console output at `warning` and above

**Read the console dump first.** It is text, it is cheap, and it catches more real bugs than
looking at pictures. Only then open the screenshots — and open the viewport most likely to
be broken, not all three.

## Step 4: Review

Read `references/ux-review.md` for what to actually look for. Short version, in priority
order:

1. **Console errors** — any uncaught error is a finding, no judgment needed
2. **Broken layout** — overflow, overlap, clipped text, horizontal scroll on mobile
3. **Broken states** — empty, loading, error, long-content. These are where UI actually fails
4. **Accessibility** — missing labels, unlabelled controls, contrast, focus order
5. **Polish** — spacing, alignment, hierarchy

Report everything you see, unfiltered. Assign severity in a **separate pass** — asking for
"only the important issues" up front makes the model report less, not better.

## Step 5: Fix and re-verify

- Fix **blocking** issues (console errors, broken layout, broken states) without asking
- Ask before **polish** changes — those are taste, and it is the user's taste that counts
- **Re-capture after fixing.** A fix you didn't look at is a guess
- Max **3 rounds.** Still broken after three means the problem is the design or the data,
  not the CSS. Stop and say so

## Report

```
FRONTEND VERIFY — <scope>
  Routes:   <n>   Viewports: 375 / 768 / 1440
  Console:  <n> errors, <n> warnings
  Fixed:    <n>    Remaining: <n>
  Artifacts: .playwright-cli/

BLOCKING
  <route> @ <viewport> — <issue> → <fix applied, or why not>

POLISH (not applied — your call)
  <route> — <suggestion>

NOT COVERED
  <routes or states you could not reach, and why>
```

Always state what you could not reach. A report that silently skips the checkout flow
because it needed a seeded cart reads as "checkout is fine".

## Rules

- **Never fake a capture.** If the browser failed, say so. An invented description of a page
  you did not load is the worst possible output here.
- **Screenshots are evidence, not decoration.** Reference the file path in each finding.
- **Don't restyle what you weren't asked about.** Same surgical rule as any other change:
  every diff line traces to a finding.
- **`.playwright-cli/` is gitignored** — `~/.claude/skills/frontend-verify/scripts/capture.sh` adds the rule if missing.

## Related

- `references/setup.md` — install, CDP attach, troubleshooting
- `references/ux-review.md` — the review criteria in full
- `/reviewer` — code-level review; this is the browser-level counterpart

---

<sub>Script paths above assume a user-level install (`~/.claude/skills/`). Installed as a
plugin or per-project, the scripts still sit beside this file — swap the prefix for
`${CLAUDE_PLUGIN_ROOT}/skills/frontend-verify` or `.claude/skills/frontend-verify` respectively.</sub>

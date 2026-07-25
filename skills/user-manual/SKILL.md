---
name: user-manual
description: >
  Builds a print-quality PDF user manual for an application — learns the
  product by reading the codebase, drives the real UI with Playwright to
  capture screenshots, writes the prose against what was actually captured,
  and renders a paginated PDF with cover, table of contents, figures and
  callouts. Use when asked for a user manual, operator guide, onboarding
  handbook, client handover documentation, or training material.
  Trigger: "make a user manual", "write documentation for this app",
  "operator guide", "client handover doc", "PDF manual", "training guide".
---

# User Manual — Read the Code, Drive the UI, Ship a PDF

Three passes, in this order, and the order is the point:

1. **Learn** the product from the codebase — routes, roles, what each screen is for
2. **Capture** every screen by driving the real app
3. **Write** the prose *against the captured screenshots*, then render

**Never write the manual first.** Prose written before capture describes the UI you imagine,
and every mismatch survives into a document a customer reads. Screens get renamed, buttons
move, fields you were sure existed don't.

## Step 0: Scaffold

```bash
~/.claude/skills/user-manual/scripts/init.mjs docs/user-manual
```

Creates the working directory, `package.json`, `manual.config.json`, and an HTML skeleton
wired to `assets/manual.css`. Then `npm install`.

## Step 1: Learn the product

Read the codebase, don't ask the user to explain their own app:

- **Routes** — the router config or file-based route tree. This is the chapter list.
- **Navigation** — the sidebar or nav component gives you the user's mental model and the
  order chapters should follow. Follow the app's order, not the filesystem's.
- **Roles and permissions** — who sees what. A manual that documents admin-only screens for
  an operator audience is worse than no manual.
- **Forms** — field names, validation rules, required vs optional. This is where manuals
  earn their keep; it is what people actually look things up for.
- **Empty and error states** — what users hit when something goes wrong.
- Existing `README`, `docs/`, ADRs — for vocabulary. **Use the product's words**, not
  synonyms you prefer. If the UI says "counterparty", the manual says counterparty.

Produce a chapter outline and **confirm it before capturing.** Capturing the wrong 30
screens is the expensive mistake here.

## Step 2: Plan the captures

Edit `manual.config.json`. One entry per figure, named to match its chapter — `01-login`,
`02-dashboard`, `03b-export-dialog`.

```json
{
  "baseUrl": "http://localhost:3000",
  "viewport": { "width": 1440, "height": 900 },
  "auth": { "path": "/login", "email": "input[type=email]", "password": "input[type=password]", "submit": "button[type=submit]" },
  "shots": [
    { "name": "01-login", "path": "/login", "fullPage": false, "noAuth": true },
    { "name": "02-dashboard", "path": "/dashboard", "delay": 1500 },
    { "name": "03b-export", "path": "/orders", "fullPage": false,
      "actions": [{ "clickRole": ["button", "Export"] }, { "wait": 800 }] }
  ]
}
```

Credentials come from the environment — `MANUAL_EMAIL`, `MANUAL_PASSWORD`. **Never put them
in the config, the scripts, or the transcript.** The capture script refuses to run if auth
is configured and they're unset.

Seed data matters as much as the code. Screenshots of empty tables teach nothing; screenshots
of real customer records are a data-protection incident. Use a demo tenant with realistic
fake data.

## Step 3: Capture

```bash
MANUAL_EMAIL=... MANUAL_PASSWORD=... npm run capture
```

Retina (`deviceScaleFactor: 2`), animations disabled, full-page by default. Dialogs and
focused states use `fullPage: false` — a full-page shot of a modal is mostly backdrop.

Missing shots are reported, never invented. **Review the screenshots before writing a word.**

## Step 4: Write against what you captured

Per chapter: what the screen is for → the figure → numbered steps → field reference table →
callouts for anything that loses data or money.

- Write to the figure in front of you. If the screenshot contradicts your sentence, the
  screenshot is right.
- Steps are numbered and imperative: "Click **Export**", not "the user may click export".
- Field tables are the most-used part of any manual. Include validation rules and what
  happens when they fail.
- Callouts: `.callout` for context, `.warning` for surprising behaviour, `.danger` for
  irreversible actions.

Layout rules and the component classes are in `references/layout.md`.

## Step 5: Build and verify

```bash
npm run build
```

Then **check the PDF** — a build that exits 0 and produces a broken document is the normal
failure here:

- Page count is plausible
- **No blank figures.** The classic bug: images not decoded before print
- No figure split across a page break
- Backgrounds and brand colour present (needs `printBackground` + `print-color-adjust`)
- TOC page numbers match reality
- File size sane — 25 retina screenshots run 5–15 MB

## Rules

- **Never fabricate a screenshot or describe a screen you did not capture.** If a screen
  couldn't be reached, list it as not covered.
- **No real customer data** in any figure. Demo tenant, fake records.
- **No credentials** in config, scripts, HTML, or the PDF. Check the login screenshot for a
  filled-in email before shipping.
- **Regenerate, don't patch.** When the UI changes, re-capture and rebuild. A manual with
  screenshots from two releases ago is actively misleading.
- Commit `manual.html` and the config; **gitignore `screenshots/` and the PDF** unless the
  client needs them in-repo.

## Related

- `references/capture.md` — auth, flaky states, dialogs, charts, troubleshooting
- `references/layout.md` — print CSS, page breaks, figures, callouts, tables, TOC
- `assets/manual.css` — the stylesheet the skeleton uses; restyle per brand

---

<sub>Script paths above assume a user-level install (`~/.claude/skills/`). Installed as a
plugin or per-project, the scripts still sit beside this file — swap the prefix for
`${CLAUDE_PLUGIN_ROOT}/skills/user-manual` or `.claude/skills/user-manual` respectively.</sub>

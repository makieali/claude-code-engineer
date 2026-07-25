# Setup and troubleshooting

## Contents
- Install
- Why CLI and not MCP
- Authenticated pages (attach to your real browser)
- Command reference
- Troubleshooting

## Install

```bash
npm install -g @playwright/cli
npx playwright install --with-deps        # browser binaries
```

Verify: `playwright-cli --version`. If the binary name differs, `scripts/capture.sh` probes
for it and falls back to `npx --no-install @playwright/cli`.

## Why CLI and not MCP

Both drive a real browser. The difference is where the output goes.

| | Playwright MCP | Playwright CLI |
|---|---|---|
| Screenshots / a11y trees | Streamed into the model's context | Written to `.playwright-cli/` on disk |
| Tool schemas | Loaded into every session | None |
| Typical task cost | ~114k tokens | ~27k tokens |

Roughly 4× on the Playwright team's own benchmark. The mechanism is simple: the CLI saves
artifacts to disk and the agent reads only what it needs, instead of every snapshot landing
in context whether it mattered or not.

**Rule:** CLI when the agent has filesystem access — Claude Code, Cursor, Copilot. MCP only
when it doesn't.

*Verified 2026-07-25. The CLI shipped early 2026 and is moving fast; re-check flags with
`--help` if a command is rejected.*

## Authenticated pages

A fresh browser context has no session, so it hits the login wall and you end up reviewing a
redirect. Two options:

**Attach to your real browser** (simplest — it's already logged in):

```bash
playwright-cli attach --extension
```

**Or log in once and reuse the state** — sign in through the driven browser on the first
run, then keep using the same session for the rest of the review.

Never put real credentials in the skill, a script, or the transcript. If a page needs a
login the agent cannot reach, say the route was not covered rather than guessing at what it
looks like.

## Command reference

| Command | Does |
|---|---|
| `open [url]` | **Open the browser. Required first** — see below |
| `goto <url>` | Navigate |
| `screenshot [target]` | Capture; `--filename` `--full-page` `--hires` |
| `snapshot [target]` | Accessibility tree → YAML on disk |
| `console [min-level]` | Read console messages |
| `resize <w> <h>` | Set viewport |
| `eval <func> [target]` | Execute JavaScript in the page |
| `find [text]` | Search the snapshot for text |
| `click` / `fill` / `press` / `hover` | Interact |
| `close` / `detach` | Tear down |

Verified against `@playwright/cli` 0.1.17 on 2026-07-26.

### Three traps, all found by running it

**`goto` does not start a browser.** A bare `goto` fails with
`The browser 'default' is not open, please run open first`. Call `open` once, then `goto`
per URL, then `close`. `capture.sh` does this and traps EXIT so the browser is not left
running.

**`--filename` must be absolute.** The CLI resolves a relative path against its own browser
process, not your shell — so `--filename shot.png` writes somewhere you will never find, and
**exits 0**. Absolute paths work.

**Exit 0 does not mean an artefact exists.** Those two facts combine into a script that
cheerfully reports three screenshots it did not take. Check the file, not the status code —
`capture.sh` now tests `[ -s "$SHOT" ]` and prints the byte count.

Artifacts land in `.playwright-cli/` with timestamped filenames unless you pass an absolute
`--filename`.

## Troubleshooting

**`NAV_FAILED`** — dev server isn't up, or it's on a different port. Run
`scripts/dev-server.sh`.

**Screenshot is blank or shows a spinner** — the page hadn't finished rendering. Increase
the settle delay in `capture.sh`, or wait on a real selector instead of a timer.

**A flag is rejected** — the CLI is new and its surface moves. Run `<command> --help` and
adjust; don't work around it by switching to the MCP.

**Fonts or images differ from your browser** — headless has a different font stack. Judge
layout and behaviour from headless captures; judge final visual polish in a headed browser.

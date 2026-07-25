# Capture recipe

## Contents
- Config shape
- Actions
- Timing — why not networkidle
- Auth
- Dialogs, tabs, charts
- Data in screenshots
- Troubleshooting

## Config shape

`manual.config.json`:

| Key | Purpose |
|---|---|
| `baseUrl` | App root. Override per-run with `MANUAL_BASE_URL` |
| `viewport` | Default `1440x900`. Screenshots always render at `deviceScaleFactor: 2` |
| `auth` | `{ path, email, password, submit }` — selectors only, never credentials |
| `shots[]` | One entry per figure |
| `title`, `brandName`, `output` | Used by the PDF header, footer and filename |

Per shot:

| Key | Effect |
|---|---|
| `name` | Filename and figure order. Number them: `01-login`, `03b-export` |
| `path` | Appended to `baseUrl` |
| `fullPage` | Default `true`. Use `false` for dialogs and focused states |
| `delay` | Settle time in ms. Default 1200. Charts and maps want 2000+ |
| `noAuth` | Capture before signing in — the login screen itself |
| `actions[]` | Interactions to perform before the shot |

## Actions

```json
{ "clickRole": ["button", "Export"] }   // preferred — resilient to markup changes
{ "clickText": "Add client" }
{ "click": ".css-selector" }
{ "fill": ["input[name=q]", "acme"] }
{ "press": "Escape" }
{ "wait": 800 }
```

Prefer `clickRole` — role and accessible name survive refactors that break CSS selectors.
Missing elements skip the action with a log line rather than aborting the run, so one
renamed button doesn't cost you the other 29 figures.

## Timing — why not networkidle

`waitUntil: 'networkidle'` never fires in apps with polling, websockets, or SSE — the run
hangs until timeout. The scripts use `domcontentloaded` plus a fixed settle delay instead.

Blank or half-rendered figure? Raise that shot's `delay`. Cheaper than fighting a load-state
heuristic in a live app.

## Auth

Credentials come from `MANUAL_EMAIL` / `MANUAL_PASSWORD` at run time. The script exits if
`auth` is configured and they're unset — capturing 30 screenshots of a login redirect and
calling it a manual is the failure this prevents.

SSO or a magic link? Log in manually once with `"headless": false` in the config and let the
session carry the run.

**Check the login screenshot before shipping.** It is the one figure that can contain a real
email address, because it is the one taken while typing one.

## Dialogs, tabs, charts

- **Dialogs** — `fullPage: false`, otherwise the shot is mostly backdrop. Follow with
  `{ "press": "Escape" }` before the next shot so the modal doesn't bleed into it.
- **Tabs** — one shot per tab, each with its own `clickRole` action and its own name.
- **Charts** — `delay: 2000+`. Chart libraries animate on mount and a shot mid-animation
  looks broken. `animations: 'disabled'` handles CSS, not canvas rendering.
- **Long pages** — `fullPage: true` produces a very tall image that shrinks to unreadable in
  print. Screenshot a meaningful section instead, or split into two figures.

## Data in screenshots

This is the part that gets people in trouble.

- **Never real customer data.** A manual gets emailed, printed, and archived. Use a demo
  tenant.
- **Never empty tables.** Empty states teach nothing about the screen. Seed realistic
  records.
- Amounts, names, and dates should look plausible. Obvious dummy data ("test test", "asdf")
  reads as unfinished work.

## Troubleshooting

**All figures blank** — the app didn't load. Check `baseUrl` and that the dev server is up.

**Some figures blank** — `delay` too low for those routes.

**Login fails** — the selectors in `auth` don't match. Open the login page and check.
`input[type=email]` fails on forms using `type="text"` for the username.

**Different fonts than your browser** — headless has its own font stack. Fine for structure;
if brand typography matters in print, install the fonts on the machine running the capture.

**Run hangs** — almost always `networkidle`. Confirm the scripts weren't edited to use it.

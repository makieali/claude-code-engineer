# What to look for

## Contents
- Priority order
- 1. Console
- 2. Layout
- 3. States — where UI actually fails
- 4. Accessibility
- 5. Polish
- Severity
- What not to report

## Priority order

Work top-down. Most reviews stop being useful past 3 because everything below it is taste.

1. Console errors — objective, no judgment
2. Broken layout — visible, uncontroversial
3. Broken states — where real bugs live
4. Accessibility — objective, usually ignored
5. Polish — subjective, ask first

## 1. Console

Any uncaught error is a finding. No severity call needed — it's already broken.

- Uncaught exceptions, unhandled rejections
- Failed network requests (4xx/5xx), especially silent ones
- React key warnings, hydration mismatches — these predict real bugs
- CSP violations, mixed content
- 404s on fonts, images, chunks

Cheapest signal in the whole review, and text, so read it before opening a single image.

## 2. Layout

At 375, 768, 1440:

- Horizontal scroll at 375 — the most common real defect and the easiest to miss on a laptop
- Text clipped, truncated mid-word, or overflowing its container
- Overlapping elements
- Off-screen or unreachable controls
- Images stretched, squashed, or without dimensions (layout shift)
- Fixed/sticky elements covering content at short viewport heights
- Tables and code blocks that don't scroll inside their own container

## 3. States — where UI actually fails

The happy path with three seeded rows almost always looks fine. Check what nobody checks:

- **Empty** — zero items. Is there a message, or a blank rectangle?
- **Loading** — is there a skeleton, or does the layout jump when data lands?
- **Error** — kill the network and reload. Does it say what went wrong, or spin forever?
- **Long content** — a 200-character name, a 500-item list. What breaks?
- **Single item** — grids often collapse oddly with exactly one child
- **Slow network** — throttle. Does anything render before data?

Trigger these with `run-code` where you can rather than assuming.

## 4. Accessibility

From the snapshot, not by eye:

- Buttons and links with no accessible name (icon-only controls are the usual culprit)
- Form inputs with no associated label
- Images missing `alt` (decorative ones need `alt=""`, not nothing)
- Heading levels skipping (h1 → h3)
- Focus order following the DOM rather than the visual layout
- No visible focus indicator on keyboard navigation
- Colour as the only signal for state — error, required, selected
- Contrast below 4.5:1 for body text

These are objective and almost never checked. High value per unit of effort.

## 5. Polish

Report, don't fix without asking:

- Inconsistent spacing between similar elements
- Misalignment on a shared axis
- Weak hierarchy — everything the same weight
- Inconsistent border radius, shadow, or colour against the rest of the app
- Transitions that are janky or too slow
- Hover/active/disabled states missing on interactive elements

## Severity

Assign in a **separate pass** from finding. Asking for "only important issues" while
looking makes the model report less, not better.

- **Blocking** — console error, unusable at a viewport, broken state, inaccessible control
- **Should fix** — real but survivable: minor overflow, weak contrast, missing hover
- **Polish** — taste. The user's call, not yours

## What not to report

- Pre-existing issues outside the diff — mention once, don't block on them
- "It could be more modern" — not a finding
- Design choices that are consistent with the rest of the app. Consistency beats your
  preference; if the whole app uses that radius, it isn't a bug
- Anything you did not actually load. Never describe a page you failed to capture

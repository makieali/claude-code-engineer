# Print layout

## Contents
- The three settings that matter
- Page breaks
- Components
- Table of contents
- Verifying the PDF
- Troubleshooting

## The three settings that matter

Miss any one and the PDF is visibly wrong:

| Setting | Where | Without it |
|---|---|---|
| `printBackground: true` | `page.pdf()` | Every brand colour, callout and table header prints white |
| `print-color-adjust: exact` | CSS on `html` | Same, from the CSS side. You need both |
| `preferCSSPageSize: true` | `page.pdf()` | `@page` is ignored and your margins are wrong |

Use `pt` and `mm` for print, not `px`. `px` in a paged medium is a guess about DPI.

## Page breaks

```css
section.chapter  { page-break-before: always; }   /* each chapter starts a page */
figure.shot      { page-break-inside: avoid; }    /* never slice a screenshot */
.callout, table  { page-break-inside: avoid; }
ol.steps li      { page-break-inside: avoid; }    /* keep a step with its number */
```

`page-break-inside: avoid` on a figure taller than one page does nothing — the browser has
nowhere to put it. Split the screenshot into two figures instead.

**Long tables** are the exception: they must break. Let them, and repeat the header:

```css
table.long        { page-break-inside: auto; }
table.long thead  { display: table-header-group; }
```

## Components

Available in `assets/manual.css`:

| Class | For |
|---|---|
| `.cover` | Full-bleed title page. Negative margins push it past the `@page` margin |
| `.toc` | Contents with dotted leaders and page numbers |
| `section.chapter` | Chapter — starts on a new page, branded heading rule |
| `figure.shot` + `figcaption` | Screenshot with caption bar |
| `.callout` / `.warning` / `.danger` | Note, surprising behaviour, irreversible action |
| `ol.steps` | Numbered circles |
| `table` / `table.long` | Field reference tables |
| `code`, `.field` | Inline UI labels and field names |
| `.keep-together` | Force any block to stay on one page |

`.danger` is for actions that lose data or money. Using it for anything else spends the
reader's attention, and they stop noticing it.

## Table of contents

Page numbers are typed by hand — Chromium's `page.pdf()` has no cross-reference pass, so
nothing computes them for you.

Write the chapters first, build once, read the real page numbers off the PDF, then fill them
in and rebuild. Anyone claiming otherwise has not checked their TOC against the output.

## Verifying the PDF

The build exits 0 on plenty of broken documents. Check:

- [ ] Page count plausible
- [ ] **No blank figures** — the build reports broken sources by name and exits non-zero
- [ ] No figure sliced across a page break
- [ ] Cover gradient and table headers have colour (proves `printBackground`)
- [ ] Header and footer on every page, page numbers correct
- [ ] TOC numbers match reality
- [ ] Size sane — 25 retina screenshots run 5–15 MB
- [ ] No credentials visible in the login figure

## Troubleshooting

**Everything is white** — missing `printBackground: true` or `print-color-adjust: exact`.

**Margins ignored** — missing `preferCSSPageSize: true`, or `@page` is inside a media query
that doesn't match.

**Cover doesn't reach the paper edge** — its negative margins must match the `@page` margins
exactly. Change one, change both.

**Figure blank in the PDF but the PNG opens fine** — a path problem. The build reports the
`src` values it couldn't decode; the paths are relative to `manual.html`.

**Build hangs with no output** — an image never settles. Both known causes are fixed in
`build-pdf.mjs`: `waitUntil: 'load'` rather than `networkidle`, and the decode wait gates on
`img.complete` alone with a timeout race. If you rewrite that block, keep both.

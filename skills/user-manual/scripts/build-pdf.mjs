#!/usr/bin/env node
/**
 * Render manual.html to a paginated PDF via Chromium.
 *
 *   node build-pdf.mjs [output.pdf]
 */
import { chromium } from 'playwright'
import { readFile, stat } from 'node:fs/promises'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

const CWD = process.cwd()
const HTML = path.join(CWD, 'manual.html')
const cfg = JSON.parse(await readFile(path.join(CWD, 'manual.config.json'), 'utf8').catch(() => '{}'))

const title = cfg.title || 'User Manual'
const brand = cfg.brandName || ''
const OUT = path.resolve(process.argv[2] || cfg.output || `${title.replace(/\s+/g, '-')}.pdf`)

const chrome = `font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;font-size:8pt;
  color:#9CA3AF;width:100%;padding:0 14mm;display:flex;justify-content:space-between;align-items:center;`

const headerTemplate = `<div style="${chrome}">
  <span style="color:#374151;font-weight:600;letter-spacing:.04em;">${brand}</span>
  <span>${title}</span></div>`

const footerTemplate = `<div style="${chrome}">
  <span>${brand ? brand + ' — ' : ''}${title}</span>
  <span>Page <span class="pageNumber"></span> of <span class="totalPages"></span></span></div>`

const browser = await chromium.launch({ headless: true })
const page = await browser.newPage()

console.log(`Loading ${HTML}`)
// 'load', not 'networkidle'. networkidle never settles when an image 404s — the
// build hangs with no output instead of reporting the broken figure. The explicit
// image-decode wait below is a stronger guarantee anyway, so networkidle bought
// nothing and cost the failure mode this script exists to catch.
await page.goto(pathToFileURL(HTML).toString(), { waitUntil: 'load', timeout: 30000 })

// Chromium prints before images finish decoding, which produces blank figures in
// an otherwise perfect PDF. Block until every image settles.
//
// Two traps here, both of which deadlock the build with no output:
//  1. Gate on `complete` ALONE, not `complete && naturalWidth`. A 404'd image is
//     already complete with naturalWidth 0 — treating it as "still loading" waits
//     for an event that fired before this code ran.
//  2. Race every wait against a timeout. An image that never fires either event
//     would otherwise hang forever.
const imageReport = await page.evaluate(async () => {
  const imgs = Array.from(document.images)
  await Promise.all(imgs.map((img) =>
    img.complete
      ? Promise.resolve()
      : Promise.race([
          new Promise((res) => { img.onload = img.onerror = () => res() }),
          new Promise((res) => setTimeout(res, 10000)),
        ])))
  return {
    total: imgs.length,
    broken: imgs.filter((i) => !i.naturalWidth).map((i) => i.getAttribute('src')),
  }
})

console.log(`Images: ${imageReport.total} total, ${imageReport.broken.length} broken`)
if (imageReport.broken.length) {
  console.error('BROKEN IMAGE SOURCES — these render blank in the PDF:')
  for (const s of imageReport.broken) console.error(`  ${s}`)
  console.error('Fix the paths or re-run capture before shipping this.')
}

console.log('Rendering…')
await page.pdf({
  path: OUT,
  format: cfg.pageFormat || 'A4',
  printBackground: true,       // without this every brand colour and callout is white
  preferCSSPageSize: true,     // honours @page in the stylesheet
  displayHeaderFooter: true,
  headerTemplate,
  footerTemplate,
  margin: cfg.margin || { top: '22mm', bottom: '22mm', left: '16mm', right: '16mm' },
})

await browser.close()

const { size } = await stat(OUT)
console.log(`\n✓ ${OUT}`)
console.log(`  ${(size / 1024 / 1024).toFixed(1)} MB`)
console.log('\nOpen it and check: no blank figures, no figure split across pages,')
console.log('backgrounds present, TOC page numbers correct.')
process.exit(imageReport.broken.length ? 1 : 0)

#!/usr/bin/env node
/**
 * Config-driven screenshot capture for a user manual.
 *
 * Reads manual.config.json, drives the real app with Playwright, writes
 * PNGs into ./screenshots named to match the manual's figures.
 *
 *   MANUAL_EMAIL=… MANUAL_PASSWORD=… node capture.mjs
 */
import { chromium } from 'playwright'
import { mkdir, readFile } from 'node:fs/promises'
import path from 'node:path'

const CWD = process.cwd()
const CONFIG = path.join(CWD, 'manual.config.json')
const SHOTS = path.join(CWD, 'screenshots')

const cfg = JSON.parse(await readFile(CONFIG, 'utf8'))
const BASE = process.env.MANUAL_BASE_URL || cfg.baseUrl
if (!BASE) throw new Error('No baseUrl in manual.config.json and no MANUAL_BASE_URL set.')

// Credentials never live in the config file. Fail loudly rather than capturing
// 30 screenshots of a login redirect and calling it a manual.
if (cfg.auth) {
  if (!process.env.MANUAL_EMAIL || !process.env.MANUAL_PASSWORD) {
    console.error('auth is configured but MANUAL_EMAIL / MANUAL_PASSWORD are unset.')
    console.error('Export them for this run. Do not put them in manual.config.json.')
    process.exit(1)
  }
}

await mkdir(SHOTS, { recursive: true })

const results = { captured: [], skipped: [] }

async function settle(page, delay = 1200) {
  // networkidle is unreliable in apps with polling, websockets or SSE — it never
  // fires and the capture times out. A fixed settle beats a promise that never resolves.
  await page.waitForLoadState('domcontentloaded').catch(() => {})
  await page.waitForTimeout(delay)
}

async function shot(page, name, opts = {}) {
  const file = path.join(SHOTS, `${name}.png`)
  await settle(page, opts.delay)
  await page.screenshot({
    path: file,
    fullPage: opts.fullPage !== false,
    animations: 'disabled',
  })
  results.captured.push(name)
  console.log(`  ✓ ${name}.png`)
}

async function runActions(page, actions = []) {
  for (const a of actions) {
    try {
      if (a.wait) { await page.waitForTimeout(a.wait); continue }
      if (a.press) { await page.keyboard.press(a.press); continue }
      if (a.fill) { await page.fill(a.fill[0], a.fill[1]); continue }
      if (a.click) { await page.click(a.click); continue }
      if (a.clickRole) {
        const [role, name] = a.clickRole
        const el = page.getByRole(role, { name: new RegExp(name, 'i') }).first()
        // count() first: a missing control should skip the figure, not abort the run.
        if (await el.count()) await el.click()
        else console.log(`    · no ${role} matching "${name}" — action skipped`)
        continue
      }
      if (a.clickText) {
        const el = page.getByText(new RegExp(a.clickText, 'i')).first()
        if (await el.count()) await el.click()
        continue
      }
      console.log(`    · unknown action: ${JSON.stringify(a)}`)
    } catch (err) {
      console.log(`    · action failed (${err.message.split('\n')[0]}) — continuing`)
    }
  }
}

async function login(page) {
  const { path: loginPath, email, password, submit } = cfg.auth
  console.log('Authenticating…')
  await page.goto(`${BASE}${loginPath}`, { waitUntil: 'domcontentloaded' })
  await page.fill(email, process.env.MANUAL_EMAIL)
  await page.fill(password, process.env.MANUAL_PASSWORD)
  await page.click(submit)
  await page.waitForURL((u) => !u.pathname.includes(loginPath), { timeout: 20000 })
  console.log('  ✓ authenticated')
}

const browser = await chromium.launch({ headless: cfg.headless !== false })
const context = await browser.newContext({
  viewport: cfg.viewport || { width: 1440, height: 900 },
  deviceScaleFactor: 2,          // retina — screenshots are reproduced large in print
  ...(cfg.locale ? { locale: cfg.locale } : {}),
})
const page = await context.newPage()

const consoleErrors = []
page.on('console', (m) => m.type() === 'error' && consoleErrors.push(m.text()))

try {
  // Shots flagged noAuth (the login screen itself) must run before signing in.
  const pre = cfg.shots.filter((s) => s.noAuth)
  const post = cfg.shots.filter((s) => !s.noAuth)

  for (const s of pre) {
    console.log(`${s.name}…`)
    await page.goto(`${BASE}${s.path}`, { waitUntil: 'domcontentloaded' })
    await runActions(page, s.actions)
    await shot(page, s.name, s)
  }

  if (cfg.auth) await login(page)

  for (const s of post) {
    console.log(`${s.name}…`)
    try {
      await page.goto(`${BASE}${s.path}`, { waitUntil: 'domcontentloaded' })
      await runActions(page, s.actions)
      await shot(page, s.name, s)
    } catch (err) {
      results.skipped.push({ name: s.name, reason: err.message.split('\n')[0] })
      console.log(`  ✗ ${s.name} — ${err.message.split('\n')[0]}`)
    }
  }
} finally {
  await browser.close()
}

console.log(`\n=== CAPTURED ${results.captured.length}/${cfg.shots.length} ===`)
if (results.skipped.length) {
  console.log('MISSING — list these as "not covered", never invent them:')
  for (const s of results.skipped) console.log(`  ${s.name}: ${s.reason}`)
}
if (consoleErrors.length) {
  console.log(`\nConsole errors during capture (${consoleErrors.length}) — the app may be`)
  console.log('misbehaving, which means some figures show a broken screen:')
  for (const e of [...new Set(consoleErrors)].slice(0, 8)) console.log(`  ${e.slice(0, 160)}`)
}
console.log(`\nScreenshots: ${SHOTS}`)
console.log('Review them before writing any prose.')
process.exit(results.skipped.length ? 1 : 0)

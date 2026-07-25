#!/usr/bin/env node
/**
 * Scaffold a manual working directory.
 *   node init.mjs [dir]        default: docs/user-manual
 */
import { mkdir, writeFile, copyFile, access } from 'node:fs/promises'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const SKILL = path.dirname(HERE)
const DIR = path.resolve(process.argv[2] || 'docs/user-manual')

const exists = async (p) => access(p).then(() => true, () => false)

await mkdir(path.join(DIR, 'screenshots'), { recursive: true })
await mkdir(path.join(DIR, 'assets'), { recursive: true })

const write = async (rel, content) => {
  const p = path.join(DIR, rel)
  if (await exists(p)) return console.log(`  · ${rel} exists, left alone`)
  await writeFile(p, content)
  console.log(`  ✓ ${rel}`)
}

await write('package.json', JSON.stringify({
  name: path.basename(DIR), private: true, type: 'module',
  scripts: { capture: 'node capture.mjs', build: 'node build-pdf.mjs' },
  dependencies: { playwright: '^1.59.0' },
}, null, 2) + '\n')

await write('manual.config.json', JSON.stringify({
  title: 'User Manual',
  brandName: '',
  output: 'User-Manual.pdf',
  baseUrl: 'http://localhost:3000',
  viewport: { width: 1440, height: 900 },
  auth: { path: '/login', email: 'input[type=email]', password: 'input[type=password]', submit: 'button[type=submit]' },
  shots: [
    { name: '01-login', path: '/login', fullPage: false, noAuth: true },
    { name: '02-dashboard', path: '/', delay: 1500 },
  ],
}, null, 2) + '\n')

await write('manual.html', `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>User Manual</title>
<link rel="stylesheet" href="assets/manual.css">
</head>
<body>

<div class="cover">
  <div><div class="meta">BRAND</div></div>
  <div>
    <h1>User Manual</h1>
    <p class="meta">Version 1.0 &middot; <!-- date --></p>
  </div>
  <div class="meta">Prepared for &lt;client&gt;</div>
</div>

<div class="toc">
  <h2>Contents</h2>
  <ol>
    <li><span>Getting started</span><span class="pageno">3</span></li>
    <li><span>Dashboard</span><span class="pageno">4</span></li>
  </ol>
</div>

<section class="chapter">
  <h2>Getting started</h2>
  <p class="chapter-intro">What this chapter covers and who it is for.</p>

  <figure class="shot">
    <img src="screenshots/01-login.png" alt="Sign-in screen">
    <figcaption>Figure 1 — Sign-in</figcaption>
  </figure>

  <ol class="steps">
    <li>Enter the email address your administrator issued.</li>
    <li>Enter your password and click <code>Sign in</code>.</li>
  </ol>

  <div class="callout">
    <strong>Note</strong>
    Sessions expire after inactivity; you will be returned to this screen.
  </div>

  <table>
    <thead><tr><th>Field</th><th>Required</th><th>Notes</th></tr></thead>
    <tbody><tr><td class="field">email</td><td>Yes</td><td>Must be a registered address.</td></tr></tbody>
  </table>
</section>

</body>
</html>
`)

for (const [src, dest] of [
  [path.join(SKILL, 'assets/manual.css'), 'assets/manual.css'],
  [path.join(HERE, 'capture.mjs'), 'capture.mjs'],
  [path.join(HERE, 'build-pdf.mjs'), 'build-pdf.mjs'],
]) {
  const target = path.join(DIR, dest)
  if (await exists(target)) { console.log(`  · ${dest} exists, left alone`); continue }
  await copyFile(src, target)
  console.log(`  ✓ ${dest}`)
}

console.log(`\nScaffolded ${DIR}

  cd ${path.relative(process.cwd(), DIR) || '.'}
  npm install && npx playwright install chromium

Then: read the codebase, confirm the chapter outline, fill manual.config.json,
capture, and only then write the prose.

Add to .gitignore:  ${path.relative(process.cwd(), DIR)}/screenshots/  and  *.pdf
`)

# Investigate — workflow mode

```javascript
export const meta = {
  name: 'investigate',
  description: 'Multi-dimension codebase investigation with adversarial verification',
  phases: [
    { title: 'Investigate', detail: 'one agent per selected dimension' },
    { title: 'Refute', detail: 'independently attack every finding' },
  ],
}

const { problem, dimensions } = args   // dimensions selected per the table above

const FINDINGS = {
  type: 'object',
  required: ['dimension', 'verdict', 'findings'],
  properties: {
    dimension: { type: 'string' },
    verdict: { type: 'string', enum: ['green', 'yellow', 'red'] },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['claim', 'evidence', 'severity', 'confidence'],
        properties: {
          claim: { type: 'string' },
          evidence: { type: 'string', description: 'path:line. Required. No evidence, no finding.' },
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
          confidence: { type: 'string', enum: ['confirmed', 'suspected'] },
        },
      },
    },
  },
}

const REFUTATION = {
  type: 'object',
  required: ['refuted', 'reason'],
  properties: {
    refuted: { type: 'boolean' },
    reason: { type: 'string' },
  },
}

const results = await pipeline(
  dimensions,
  d => agent(
    `${d.brief}\n\nPROBLEM: ${problem}\n\n` +
    `Every finding must cite path:line. If you cannot cite it, do not report it. ` +
    `Mark anything you did not verify as confidence "suspected".`,
    { label: `investigate:${d.key}`, phase: 'Investigate',
      schema: FINDINGS, model: d.model, effort: d.effort }),

  // Refute each finding as soon as its dimension returns — no barrier.
  (report, d) => parallel(((report && report.findings) || []).map(f => () =>
    agent(
      `Try to REFUTE this finding. Read the cited code yourself.\n\n` +
      `CLAIM: ${f.claim}\nEVIDENCE: ${f.evidence}\n\n` +
      `Refuted if: the code does not say what the claim says, the path is wrong, the ` +
      `condition cannot occur, or it is already handled elsewhere. ` +
      `Default to refuted:true when the evidence does not clearly hold.`,
      { label: `refute:${d.key}`, phase: 'Refute',
        schema: REFUTATION, model: d.model, effort: 'high' })
      .then(v => ({ ...f, dimension: d.key, survived: !!(v && !v.refuted), why: v && v.reason }))
  ))
)

const all = results.flat().filter(Boolean)
const confirmed = all.filter(f => f.survived)
const refuted = all.filter(f => !f.survived)

// Cross-analysis is plain code over structured data, not another model re-reading six reports.
const byArea = {}
for (const f of confirmed) {
  const area = String(f.evidence).split(':')[0]
  if (!byArea[area]) byArea[area] = []
  byArea[area].push(f)
}
const corroborated = Object.keys(byArea)
  .map(area => ({ area, dims: [...new Set(byArea[area].map(f => f.dimension))], findings: byArea[area] }))
  .filter(x => x.dims.length >= 2)

log(`${all.length} raised · ${confirmed.length} survived refutation · ` +
    `${corroborated.length} areas flagged by 2+ dimensions`)

return { confirmed, refuted, corroborated }
```

`pipeline` and not `parallel` between the stages on purpose: the architecture lane's findings
start being refuted while the security lane is still reading. A barrier there would waste the
fast lanes' wall-clock for nothing — nothing in the refute step needs the other dimensions.

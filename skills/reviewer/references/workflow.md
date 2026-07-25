# Reviewer — workflow mode

The canonical shape: find across dimensions, refute each finding the moment its dimension
lands, filter once at the end.

```javascript
export const meta = {
  name: 'review-phase',
  description: 'Review an implemented phase across dimensions, refute findings, then rank',
  phases: [
    { title: 'Find', detail: 'one agent per review dimension' },
    { title: 'Refute', detail: 'independently attack every finding' },
    { title: 'Filter', detail: 'assign severity in a separate pass' },
  ],
}

const { diffBase, planDir, loadBearing } = args

const DIMENSIONS = [
  { key: 'contracts', brief: 'Compare every type, endpoint, migration and env var against plan.md Shared Contracts, field by field.' },
  { key: 'tests',     brief: 'Assess test quality. Then MUTATE the code — invert a condition, swap a boundary — and report whether tests caught it.' },
  { key: 'edges',     brief: 'Null/undefined, failure paths, timeouts, races, backward compatibility, large inputs.' },
  { key: 'security',  brief: 'Secrets, injection, XSS, authn/authz, validation at boundaries, dependency advisories, PII in logs.' },
  { key: 'perf',      brief: 'N+1 queries, unbounded fetches, blocking work, missing indexes, unevicted caches, leaked listeners.' },
  { key: 'quality',   brief: 'Style consistency, duplication, function size, naming, leftover debug code, type strictness.' },
]

const FOUND = {
  type: 'object',
  required: ['findings'],
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        required: ['file', 'line', 'issue'],
        properties: {
          file: { type: 'string' },
          line: { type: 'number' },
          issue: { type: 'string' },
          suggested_fix: { type: 'string' },
        },
      },
    },
  },
}

const REFUTATION = {
  type: 'object',
  required: ['refuted', 'reason'],
  properties: { refuted: { type: 'boolean' }, reason: { type: 'string' } },
}

// Load-bearing changes get three different lenses; everything else gets one refuter.
const LENSES = loadBearing
  ? ['does the code actually do what this claims',
     'is the stated impact real here or only theoretical',
     'can you construct the input or state that triggers it']
  : ['does this finding hold when you read the cited code']

const reviewed = await pipeline(
  DIMENSIONS,
  d => agent(
    `Review the diff ${diffBase}..HEAD. Plan at ${planDir}.\n\n${d.brief}\n\n` +
    `Report EVERYTHING you find at any severity. Do not filter, do not prioritise, ` +
    `do not decide something is probably fine. Cite file and line for each.`,
    { label: `find:${d.key}`, phase: 'Find', schema: FOUND,
      model: 'claude-sonnet-5', effort: 'medium' }),

  (found, d) => parallel((((found && found.findings) || [])).map(f => () =>
    parallel(LENSES.map(lens => () =>
      agent(`Attack this review finding — ${lens}?\n\n` +
            `${f.file}:${f.line} — ${f.issue}\n\n` +
            `Read the cited code. Default to refuted:true if it does not clearly hold.`,
            { label: `refute:${d.key}`, phase: 'Refute', schema: REFUTATION,
              model: 'claude-opus-5', effort: 'high' })))
      .then(votes => {
        const v = votes.filter(Boolean)
        const kills = v.filter(x => x.refuted).length
        return { ...f, dimension: d.key,
                 survived: kills < Math.ceil(v.length / 2),
                 refutation: v.map(x => x.reason) }
      })
  ))
)

const survived = reviewed.flat().filter(Boolean).filter(f => f.survived)
const killed   = reviewed.flat().filter(Boolean).filter(f => !f.survived)
log(`${survived.length} findings survived, ${killed.length} refuted`)

// Severity assigned in its own pass, by a model that did not do the finding.
const ranked = survived.length ? await agent(
  `Assign severity to each finding. critical = blocks merge (contract violation, security ` +
  `hole, data loss, broken existing behaviour). warning = real but survivable. note = ` +
  `informational.\n\n${JSON.stringify(survived, null, 2)}`,
  { label: 'filter:severity', phase: 'Filter', model: 'claude-opus-5', effort: 'high',
    schema: { type: 'object', required: ['findings'], properties: { findings: {
      type: 'array', items: { type: 'object',
        required: ['file', 'line', 'issue', 'severity'],
        properties: { file: { type: 'string' }, line: { type: 'number' },
                      issue: { type: 'string' },
                      severity: { type: 'string', enum: ['critical', 'warning', 'note'] },
                      suggested_fix: { type: 'string' } } } } } } }
) : { findings: [] }

return { ranked: ranked.findings, refuted: killed }
```

Note the two barriers that are deliberately *absent*: the security lane's findings are being
refuted while the perf lane is still reading. Only the severity filter needs everything at
once — it is ranking findings relative to each other — so that is the one place a barrier
is correct.

---

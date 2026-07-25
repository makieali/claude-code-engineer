# Architect — judge-panel mode

For plans that are expensive to get wrong — migrations, architecture with no clean answer,
anything irreversible — do not iterate on one plan. Generate several independently, score
them, and synthesize from the winner.

```javascript
export const meta = {
  name: 'plan-panel',
  description: 'Independent plan attempts from different angles, scored, then synthesized',
  phases: [{ title: 'Draft' }, { title: 'Score' }],
}

const { problem, investigation } = args

const ANGLES = [
  'Smallest shippable increment first. Optimise for landing something today.',
  'Risk first. Sequence so the scariest thing is proven earliest and is cheap to revert.',
  'Contract first. Nail every interface before any behaviour, so phases can run parallel.',
]

const SCORE = {
  type: 'object',
  required: ['score', 'strengths', 'weaknesses'],
  properties: {
    score: { type: 'number', description: '1-10' },
    strengths: { type: 'array', items: { type: 'string' } },
    weaknesses: { type: 'array', items: { type: 'string' } },
  },
}

const drafts = await parallel(ANGLES.map((angle, i) => () =>
  agent(`Produce a phased execution plan.\n\nPROBLEM: ${problem}\n` +
        `INVESTIGATION: ${investigation}\n\nANGLE: ${angle}`,
        { label: `draft:${i + 1}`, phase: 'Draft', model: 'claude-opus-5', effort: 'high' })))

const scored = await parallel(drafts.filter(Boolean).map((d, i) => () =>
  agent(`Score this plan for a team that must ship safely. Penalise phases that cannot be ` +
        `verified, contracts that are vague, and dependencies that force serialisation.\n\n${d}`,
        { label: `score:${i + 1}`, phase: 'Score', schema: SCORE,
          model: 'claude-opus-5', effort: 'high' })))

return drafts.map((plan, i) => ({ angle: ANGLES[i], plan, verdict: scored[i] }))
```

Synthesize from the highest-scoring draft, grafting the specific strengths the judges named
in the others. Do not average the plans together — you get the weaknesses of all three.

---

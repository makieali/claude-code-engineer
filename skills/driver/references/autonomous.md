# Driver — autonomous mode

Advisory mode is the default and stays the default. Autonomous mode runs the pipeline end
to end without a human between phases — and it is only safe behind all four of these. If
you cannot satisfy every one, run advisory.

1. **A stop condition that can be proven, not asserted.** Every phase ends on real exit
   codes from test, lint and build, and an approved review. Not a model's opinion that it
   went well.
2. **A hard cap.** A turn or token budget for the run, and the existing 3-cycle review cap
   per phase. Without a cap it runs until someone notices the bill.
3. **Irreversible actions gated on a human.** Merges to the base branch, deploys, dependency
   upgrades, database migrations against anything real, force pushes, deletions. The
   pipeline implements and reviews them; it does not perform them.
4. **A pilot run first.** One phase, watched. Only widen once you have seen it stop on its
   own — that is the behaviour you are actually testing, and the one nobody verifies.

```javascript
export const meta = {
  name: 'drive-plan',
  description: 'Run implement → review → fix per phase, respecting dependencies',
  phases: [
    { title: 'Implement', detail: 'one executor per ready phase' },
    { title: 'Review', detail: 'fresh-context validation, up to 3 cycles' },
  ],
}

const { planDir, plan } = args
const MAX_CYCLES = 3
const approved = new Set()
const results = []

// Dependency-ordered waves. Everything inside a wave is genuinely parallel-safe,
// so each gets its own worktree and they cannot touch each other's index.
let remaining = plan.phases.slice()
while (remaining.length) {
  const ready = remaining.filter(p => (p.depends_on || []).every(d => approved.has(d)))
  if (!ready.length) {
    log(`deadlock: ${remaining.map(p => p.id).join(', ')} have unmet dependencies`)
    break
  }

  const wave = await parallel(ready.map(p => () => (async () => {
    let cycle = 0
    let verdict = null

    while (cycle < MAX_CYCLES) {
      cycle++
      await agent(
        cycle === 1
          ? `Implement phase ${p.id} from ${planDir}. Work in worktree .worktrees/phase-${p.id} ` +
            `on branch ${p.branch}. One task at a time, verify each with its command, commit each.`
          : `Fix the CRITICAL findings in ${planDir}/reviews/phase-${p.id}-cycle-${cycle - 1}.md. ` +
            `Do not widen scope beyond the findings.`,
        { label: `exec:p${p.id}:c${cycle}`, phase: 'Implement',
          model: 'claude-sonnet-5', effort: 'medium', isolation: 'worktree' })

      verdict = await agent(
        `Review phase ${p.id} in a fresh context. Report everything unfiltered, refute each ` +
        `finding, then assign severity in a separate pass. Run test, lint and build yourself ` +
        `and record the real exit codes. Any non-zero exit forces changes_required.` +
        (p.load_bearing ? ` This phase is LOAD-BEARING — attack each finding from three ` +
                          `different angles, not three identical ones.` : ''),
        { label: `review:p${p.id}:c${cycle}`, phase: 'Review',
          model: 'claude-opus-5', effort: 'high',
          schema: { type: 'object', required: ['verdict', 'critical'], properties: {
            verdict: { type: 'string', enum: ['approved', 'approved_with_notes', 'changes_required'] },
            critical: { type: 'number' },
            summary: { type: 'string' } } } })

      if (verdict && verdict.verdict !== 'changes_required') break
      log(`phase ${p.id} cycle ${cycle}: ${verdict ? verdict.critical : '?'} critical`)
    }

    const ok = !!(verdict && verdict.verdict !== 'changes_required')
    if (!ok) log(`ESCALATE phase ${p.id}: still failing after ${MAX_CYCLES} cycles — human needed`)
    return { phase: p.id, approved: ok, cycles: cycle, verdict }
  })()))

  for (const r of wave.filter(Boolean)) {
    results.push(r)
    if (r.approved) approved.add(r.phase)
  }
  remaining = remaining.filter(p => !wave.filter(Boolean).some(r => r.phase === p.id))
}

log(`${approved.size}/${plan.phases.length} phases approved`)
return { results, merged: false, note: 'Merging to the base branch is gated on a human.' }
```

Note `merged: false`. The workflow implements, reviews, and stops. Nothing in this script
touches the base branch — that is guardrail 3, and it is the one people quietly remove
first.

---

# Executor — workflow mode

```javascript
export const meta = {
  name: 'execute-phase',
  description: 'Implement each task in a phase, verify, and commit',
  phases: [{ title: 'Implement', detail: 'one agent per task, in order' }],
}

const { planDir, phase, tasks, commands } = args

const RESULT = {
  type: 'object',
  required: ['id', 'status'],
  properties: {
    id: { type: 'string' },
    status: { type: 'string', enum: ['done', 'failed'] },
    commit: { type: 'string' },
    failure_reason: { type: 'string' },
    files_changed: { type: 'array', items: { type: 'string' } },
  },
}

const done = []
for (const t of tasks) {
  // Sequential on purpose: tasks inside a phase share files and a working tree.
  // Parallelism lives at the phase level, isolated by worktree — not here.
  const blockers = (t.depends_on || []).filter(
    id => !done.some(d => d.id === id && d.status === 'done'))
  if (blockers.length) {
    log(`skip ${t.id} — blocked by ${blockers.join(', ')}`)
    done.push({ id: t.id, status: 'failed', failure_reason: `blocked by ${blockers.join(', ')}` })
    continue
  }

  const r = await agent(
    `Implement task ${t.id} from ${planDir}/phases/phase-${phase}-*.md.\n\n` +
    `Change ONLY these files: ${(t.files_affected || []).join(', ')}.\n` +
    `Handle every edge case the task lists. Write or update the tests it specifies.\n\n` +
    `Then run, in order, and report the real exit codes:\n` +
    `  ${t.verify_command}\n  ${commands.test}\n` +
    `  ${commands.lint || '(no lint step)'}\n  ${commands.build || '(no build step)'}\n\n` +
    `All green → git add only those files, commit "${t.commit_message}", return the sha.\n` +
    `Any red → two fix attempts, then return status failed with the reason.\n\n` +
    `Do not touch shared contracts. Do not widen the task.`,
    { label: `task:${t.id}`, phase: 'Implement', schema: RESULT,
      model: 'claude-sonnet-5', effort: 'medium' })

  done.push(r || { id: t.id, status: 'failed', failure_reason: 'agent returned nothing' })

  if (r && r.status === 'failed' && (t.blocks || []).length) {
    log(`STOP — ${t.id} failed and blocks ${t.blocks.join(', ')}`)
    break
  }
}

return { phase, tasks: done,
         status: done.every(d => d.status === 'done') ? 'needs_review' : 'blocked' }
```

Run this **per phase**, one workflow per phase, with each phase in its own worktree. Do not
try to parallelise tasks inside a phase — they share files, and the isolation boundary that
makes concurrency safe is the phase, not the task.

---

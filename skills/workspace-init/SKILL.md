---
name: workspace-init
description: >
  Sets up a multi-repo workspace so one session can see a whole system —
  sibling repos plus the cross-cutting folders no single repo owns — and
  generates the root CLAUDE.md map by reading each repo rather than being
  told. Use when starting work across several related repos, onboarding
  onto an unfamiliar system, or when Claude keeps missing context that
  lives in a sibling repo.
  Trigger: "set up the workspace", "map this project", "I have several
  repos", "onboard me onto this", "create the root CLAUDE.md".
---

# Workspace Init — One Boundary Around A Whole System

Most real systems are several repositories. Opening one of them means everything else is
invisible: the API contract lives next door, the deploy config lives somewhere else, and the
agent guesses at both.

The fix is a **parent directory** holding the repos as siblings, plus the folders no single
repo can own. Open the session at the parent, and one context sees the whole system.

```
<workspace>/
├── CLAUDE.md              ← the map. What exists, where, on which port
├── <repo-a>/              ← real git repos, each with its own remote
├── <repo-b>/
├── <repo-c>/
├── server-info/           ← how to reach the machines        (GITIGNORED)
├── plans/                 ← /architect output, dated handoffs
├── project-knowledge/     ← durable knowledge, not session narrative
└── docs/                  ← runbooks, audits, decisions
```

The parent is usually **not** a git repo. If you make it one, `server-info/`, `.env`, and
anything with a credential must be ignored before the first commit — history is forever.

---

## MODEL ROUTING

| Role | Used here for | Effort |
|---|---|---|
| **bulk** | reading each repo's manifest, entrypoint, and scripts | `low` |
| **orchestrator** | writing the map, deciding what earns a line | `high` |

*Mapping as of 2026-07-25 — re-check on every model release:* bulk `claude-haiku-4-5`,
orchestrator `claude-opus-5`.

Reconnaissance across N repos is the one genuinely parallel step here — one cheap agent per
repo returning a fixed shape. Everything else is a single judgment call and should stay in
one place.

---

## STEP 1: SURVEY

```bash
# What's actually here, and which are real repos
for d in */; do
  [ -d "$d/.git" ] && printf '%-28s %s\n' "$d" "$(git -C "$d" remote get-url origin 2>/dev/null)"
done
```

For each repo, in parallel, one agent answers exactly this and nothing more:

- **Stack** — from the manifest: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`,
  `pom.xml`, `build.gradle`, `Gemfile`, `composer.json`, `Package.swift`, `*.csproj`,
  `mix.exs`, `pubspec.yaml`, `CMakeLists.txt`
- **Entrypoint** — the file or command that starts it
- **Dev / test / build / lint commands** — read from the scripts block, `Makefile`,
  `Taskfile`, or `justfile`. Do not guess. If a repo has no lint step, say so
- **Port** — from config or the entrypoint, not from assumption
- **Remote and default branch**
- **Does it already have its own `CLAUDE.md`?**

Keep the fan-out to one agent per repo. Reading a manifest is not work that needs three.

---

## STEP 2: WRITE THE ROOT MAP

`<workspace>/CLAUDE.md` is a **map, not a manual.** It answers "what exists and where",
never "how to write React". Per-repo detail belongs in that repo's own `CLAUDE.md`, which
this file points at.

**The template below assumes a deployed multi-service system.** Plenty of workspaces are
not: a set of libraries has no ports, no request path, and no environments. **Omit the
sections that do not apply and say you omitted them** — do not fill in a "How they talk"
diagram for repos that never call each other. Inventing a topology is exactly the failure
this file exists to prevent, and an empty Services table with a port column full of dashes
is worse than no table. Keep Repos, Commands, and Per-repo guidance; those apply to every
workspace.

If it grows past roughly 200 lines it has stopped being a map. Move detail down into the
repos.

```markdown
# CLAUDE.md — <workspace name>

<One paragraph: what this system does and who uses it.>

## Services

| Service | Directory | Port | Stack | Repo |
|---|---|---|---|---|
| ... | `<dir>/` | 8001 | FastAPI | `<org>/<repo>` |

## How they talk

<A diagram of the actual request path — entry point, hops, datastore, realtime channel.
This is the single highest-value block in the file. It is what stops an agent inventing
an architecture that does not exist.>

## Commands

<Per service, the real dev / test / build / lint commands. Read, not assumed.>

## Environments

| | Local | Dev | Production |
|---|---|---|---|
| API | `localhost:8001` | `<dev host>` | `<prod host>` |

Server access, credentials, and deploy detail: `server-info/` — gitignored, read it before
touching any machine.

## Repos and branches

| Repo | Remote | Default branch | Deploys to |
|---|---|---|---|

## Per-repo guidance

- `<repo-a>/CLAUDE.md` — <what it covers>
- `project-knowledge/` — durable knowledge that outlives a session
- `plans/` — /architect plans and dated handoffs

## Model routing

<Roles, not model names. Date the mapping — it decays faster than anything else here.>

<!-- Verified against vendor documentation on <date>. Re-check on the next model release. -->
```

**Date the routing section and re-check it.** This is the block that goes stale first and
silently: a workspace map written six months ago will happily route every lane to a model
that has since been superseded by something cheaper and better, and nothing will error.

---

## STEP 3: CREATE THE CROSS-CUTTING FOLDERS

```bash
mkdir -p server-info plans project-knowledge docs
```

| Folder | Holds | Committed? |
|---|---|---|
| `server-info/` | Hosts, services, deploy paths, credentials | **Never** |
| `plans/` | `/architect` output, dated handoffs | Optional |
| `project-knowledge/` | Durable knowledge: domain rules, gotchas, decisions | Yes |
| `docs/` | Runbooks, audits, incident write-ups | Yes |

`project-knowledge/` versus a handoff is worth getting right: **knowledge is what stays true
after the work ships; a handoff is what was happening on Tuesday.** Mixing them means the
durable material rots inside stale session narrative.

Then protect it, before anything is committed anywhere:

```bash
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  cat >> .gitignore <<'EOF'
server-info/
.env
.env.*
!.env.example
*.pem
*.key
secrets/
EOF
  git check-ignore -q server-info && echo "server-info/ ignored" \
    || echo "NOT IGNORED — fix before committing"
else
  echo "Parent is not a git repo. Nothing can be committed from here, so there is"
  echo "nothing to ignore. Do NOT run 'git init' to make the check pass — that is"
  echo "the one action that puts server-info/ at risk."
fi
```

**Branch on whether the parent is a repo.** Running `git check-ignore` outside one always
fails, which reads as "your gitignore is broken" when nothing is even trackable — and the
obvious fix a user reaches for is `git init`, the single action that could commit
`server-info/`. Observed, running the earlier version verbatim.

---

## STEP 4: VERIFY THE MAP

A map nobody checked is worse than none, because it is trusted.

- Every command in the file has actually been run at least once
- Every port matches what the service really binds
- Every repo URL resolves
- The request-path diagram matches the code, not the intention

Anything you could not verify gets marked `<!-- unverified -->` rather than stated.

---

## WORKING RULES ONCE THE WORKSPACE EXISTS

- **Open sessions at the parent**, not inside a single repo, whenever work crosses a
  boundary. Inside one repo, the others do not exist.
- **One session, one piece of work.** A workspace makes it easy to wander into a sibling
  repo "while you're here". That tangent becomes permanent sediment in the context.
- **Cross-repo changes are contract changes.** If a change spans repos, it wants
  `/architect` and a shared contract, not two independent edits that happen to agree today.
- **Update the map when it lies.** A new service, a changed port, a moved deploy target —
  the map is only load-bearing while it is true.

---

## AFTER

1. Read the generated `CLAUDE.md` and correct anything the survey got wrong. It was read
   from files, which means it is honest about what is there and blind to intent.
2. Run `/server-connect` for each machine — that writes `server-info/`.
3. Connect the task tracker so work items are visible from the same session.
4. From then on, `/investigate` and `/architect` start at the parent and can see everything.

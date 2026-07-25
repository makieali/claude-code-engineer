---
name: server-connect
description: >
  Gives Claude Code non-interactive SSH access to a server and then writes
  a server-info folder by interrogating the machine — services, ports,
  deploy paths, logs, databases — rather than being told. Use when adding
  a dev or production server to a workspace, onboarding onto infrastructure
  nobody documented, or when Claude cannot reach a machine it needs.
  Trigger: "connect to the server", "set up ssh", "document this server",
  "add the dev server", "why can't you reach the box".
---

# Server Connect — Reachable, Then Written Down

Two jobs, in this order:

1. **Make the server reachable by name**, non-interactively, so no session ever stalls on a
   prompt it cannot answer.
2. **Write down what is on it**, by looking rather than by asking, into `server-info/`.

The second is the part people skip, and it is the part that pays. A session that has to
rediscover which service runs on which port every time is a session spending its context on
archaeology.

---

## SAFETY RULES — read before running anything

- **Read-only until told otherwise.** Discovery does not restart services, edit configs, or
  touch a database. Every command in Step 5 is safe to run on production.
- **`server-info/` is never committed.** Verify it is gitignored *before* writing into it.
- **Never write a discovered secret into the notes.** Record that
  `DATABASE_URL` is set; never record its value. Record the path to the env file, not its
  contents.
- **Irreversible actions are gated on a human**: service restarts on production, migrations,
  firewall changes, package upgrades, anything touching data.
- Nothing here goes in a public repository. Real hostnames and usernames are the reason.

---

## STEP 1: GENERATE A KEY — no passphrase, and here is the honest tradeoff

```bash
KEY=~/.ssh/<project>-<env>          # e.g. ~/.ssh/acme-dev — one key per server, never reused
ssh-keygen -t ed25519 -N "" -C "claude-code@<project>-<env>" -f "$KEY"
chmod 600 "$KEY"
```

`-N ""` means **no passphrase.** This is deliberate and it is a real tradeoff, so decide it
consciously rather than inheriting it:

An agent cannot answer an interactive passphrase prompt. A protected key does not fail
loudly — it hangs, or the session reports a connection problem that is actually a prompt
nobody can see. Every non-interactive path (a scheduled run, a workflow lane, a deploy)
breaks the same way.

What you give up is disk-at-rest protection on the private key. Buy it back structurally:

- **One key per server per project.** Never your personal key, never shared across
  environments. Blast radius is one machine.
- **A dedicated user** on the server where you can, not root, with only the access the work
  needs.
- **Revocable and rotated.** Removing one line from `authorized_keys` ends it. Do that when
  a project finishes.
- **`chmod 600`**, and the key never leaves the machine it was generated on.

If a passphrase is genuinely required by policy, use an agent with a pre-loaded key and
accept that unattended runs will not work. Do not pretend both are available.

---

## STEP 2: INSTALL THE PUBLIC KEY

```bash
ssh-copy-id -i "$KEY.pub" <user>@<host>
```

No `ssh-copy-id`, or a jump host in the way:

```bash
cat "$KEY.pub" | ssh <user>@<host> \
  'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

Some providers only accept keys through a console or an API — cloud instances, managed
hosts. Fine: the rest of this skill is unchanged once the key is in.

---

## STEP 3: NAME IT IN `~/.ssh/config`

**The alias is the interface.** Once this exists, nothing — no skill, no script, no
workflow, no note — needs the IP address or the key path again. Change the server's address
and one line changes.

```sshconfig
Host <project>-<env>
    HostName        <ip-or-dns>
    User            <user>
    IdentityFile    ~/.ssh/<project>-<env>
    IdentitiesOnly  yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

`IdentitiesOnly yes` matters more than it looks: without it, ssh offers every key it knows,
and a server with `MaxAuthTries` set will disconnect you before reaching the right one. The
failure looks like a rejected key rather than too many keys.

Long-running commands over a flaky link are what `ServerAlive*` is for — a deploy dropping
at 80% because the connection idled is an avoidable class of problem.

---

## STEP 4: VERIFY NON-INTERACTIVELY

Do not verify by running `ssh <alias>` and seeing a shell. That proves an *interactive*
session works, which is not the thing being tested.

```bash
ssh -o BatchMode=yes -o ConnectTimeout=10 <project>-<env> 'echo OK; whoami; hostname'
```

`BatchMode=yes` disables every prompt. `OK` means an unattended agent can use this. A hang or
failure means something still wants input — fix it now, not when a scheduled run dies
silently at 3am.

Check privilege too, since half the useful commands need it:

```bash
ssh -o BatchMode=yes <project>-<env> 'sudo -n true && echo "passwordless sudo" || echo "sudo needs a password"'
```

Record the answer. It bounds what can be automated, and finding out mid-deploy is worse
than knowing now.

---

## STEP 5: INTERROGATE THE SERVER

**Do this yourself, adaptively. There is no script here on purpose.**

A fixed probe encodes a guess about what servers look like, and then reports confidently on
a server that does not match it. Measured: a script checking `/etc/nginx`, `/etc/caddy` and
`/etc/apache2` reported "no web layer" on a host serving 80 and 443 — because the reverse
proxy was a container. The evidence to catch that was three lines up in its own output, and
a script cannot notice a contradiction. You can.

Every command below is read-only and safe against production. Run what the last answer
makes relevant, not the whole list.

**Start broad:** OS and kernel, uptime, cores, memory, disk. Running services
(`systemctl list-units --type=service --state=running`), enabled-at-boot, and what is
actually bound (`sudo ss -tlnp`, falling back to `ss -tln`).

**Then follow what you found.** This is the part a script cannot do:

- Ports 80/443 served but no web server installed → **the proxy is containerised.** Check
  `docker ps` for what publishes those ports, and find the compose files — on this kind of
  host the compose file, not a systemd unit, is the deployment unit.
- A service you care about → `systemctl cat <name>.service`. The unit file is where the
  exec path, user, `WorkingDirectory` and `EnvironmentFile` actually live.
- Docker present → `docker ps` names, images and published ports tell you the topology
  faster than anything on the host filesystem.
- Code locations → `find ~ /srv /opt -maxdepth 3 -name .git` maps deployments to repos.
- Runtimes → probe for what the code needs, not a fixed list. Absence is information:
  no `node` on a host running Node containers tells you everything runs in Docker.
- Scheduled work → `crontab -l`, `/etc/cron.d/`, `systemctl list-timers`.
- Log locations, not log contents.

**Env vars: names only, never values.**

```bash
ssh <alias> 'for f in ~/*/.env /srv/*/.env /opt/*/.env; do
  [ -f "$f" ] && { echo "-- $f"; cut -d= -f1 "$f" | grep -v "^#"; }; done 2>/dev/null'
```

`cut -d= -f1` is what keeps the values out. Do not widen it, and do not paste a value into
the notes if one crosses your screen — a real host will have `POSTGRES_PASSWORD` and API
keys in there.

**Stop when the notes would be complete**, not when the list is exhausted. Write up what
you saw. Do not paraphrase from memory, and do not widen the env
scan to print values — that is how secrets end up in notes that get committed by accident.

---

## STEP 6: WRITE `server-info/`

```
server-info/
├── README.md                 index + the comparison table across environments
└── <env>/                    one folder per machine: dev, staging, prod
    ├── README.md             quick reference — the page you actually reopen
    ├── SERVER_INFO.md        OS, resources, users, paths, runtimes
    ├── SERVICES.md           per service: unit name, port, exec path, env file, logs
    ├── DEPLOYMENT.md         how code gets there, and how to roll back
    └── CREDENTIALS.md        human-maintained. The skill never writes secrets here
```

`server-info/README.md` carries the index and the cross-environment table — the thing worth
having open:

```markdown
# Server Information — <workspace>

> Never commit this folder. Verified <date>.

## Access
| Environment | SSH | User | Sudo |
|---|---|---|---|
| Dev | `ssh <project>-dev` | `<user>` | passwordless / password |
| Production | `ssh <project>-prod` | `<user>` | password required |

## Environments
| | Dev | Production |
|---|---|---|
| Services | ... | ... |
| API port | ... | ... |
| Database | ... | ... |
| Code path | ... | ... |
| Deploy | ... | ... |

## URLs
| Service | Dev | Production |
|---|---|---|
| API | `https://...` | `https://...` |
| Health | `https://.../health` | `https://.../health` |
```

Per environment, `SERVICES.md` is the file that earns its keep — for each service: unit
name, listening port, exec path, working directory, env file location, log command, and the
restart command. That table is the difference between an agent that can operate the machine
and one that greps for it every session.

**Health checks belong in every server README.** They are the cheapest external verification
available, and they are what a deploy should be gated on.

---

## STEP 7: PROTECT IT

```bash
grep -qxF 'server-info/' .gitignore || echo 'server-info/' >> .gitignore
git check-ignore -v server-info || echo "NOT IGNORED — stop and fix before committing"
```

Already committed it once? Removing the file does not remove it from history. Treat every
credential in it as exposed and rotate.

---

## WORKING RULES ONCE CONNECTED

- **Read `server-info/` before touching a machine.** That is what it is for. Rediscovering
  the layout every session is the cost this skill exists to remove.
- **Diagnose before restarting.** Logs, then status, then a change. A restart that "fixes"
  something has destroyed the evidence.
- **Production restarts, migrations, and deploys are gated on a human.** The pipeline can
  prepare and verify them; it does not perform them.
- **When the server surprises you, write it down** — into `server-info/`, not into the chat.
  A quirk discovered twice was a note that should have been written the first time.
- **Re-verify after infrastructure changes.** A new service, a moved port, a changed deploy
  path: the notes are only load-bearing while they are true. Date them.

---

## AFTER

1. Review the generated notes. Discovery is honest about what runs and blind to why.
2. Fill `CREDENTIALS.md` by hand, or better, leave it as pointers into a password manager.
3. `git check-ignore server-info` one more time before any commit anywhere near this repo.
4. Confirm the alias works from a clean shell — that is what a scheduled run will get.

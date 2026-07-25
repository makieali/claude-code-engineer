---
name: clickup-connect
description: >
  Connects Claude Code to a ClickUp workspace and writes its own reference
  notes — workspace, spaces, folders, list IDs, assignee IDs, and the API
  quirks it hits — so future sessions can read and update tasks without
  rediscovering the workspace every time. Use when wiring a task tracker
  into a workspace or when task IDs keep getting looked up by hand.
  Trigger: "connect clickup", "set up the task board", "read my tasks",
  "sync tasks", "what's assigned to me".
---

# ClickUp Connect — Discover Once, Write It Down

An agent that can read your task board closes the loop: work items, code, servers, and
review all become visible from one session. But an agent rediscovering list IDs on every
invocation spends its context on lookups.

So do it once, and have it **write its own reference file**. That file — not the chat — is
what the next session reads.

The shape here transfers to Jira, Linear, Asana, or GitHub Projects unchanged: token →
verify → discover the hierarchy → write notes → record the quirks → document the refresh.
Only the endpoints differ.

---

## STEP 1: TOKEN — gitignore first, then write it

Order matters. Ignore the file *before* it contains a secret.

```bash
mkdir -p <workspace>/task-board && cd <workspace>/task-board
printf '.env\n*.local\n' > .gitignore
git check-ignore -v .env || echo "NOT IGNORED — stop"

printf 'CLICKUP_API_TOKEN=<paste token>\n' > .env
chmod 600 .env
```

Use a **Personal API Token** (ClickUp: Settings → Apps → API Token). Note the quirk: the
header is `Authorization: <token>` with **no `Bearer` prefix**. Sending `Bearer` fails with
an auth error that reads like a bad token, which is a good half hour if you don't know.

The token carries the permissions of the human who issued it. It is not scoped down. Treat
it accordingly: gitignored, `chmod 600`, never pasted into an issue, rotated when a project
ends.

---

## STEP 2: VERIFY

```bash
set -a; source .env; set +a
curl -s -H "Authorization: $CLICKUP_API_TOKEN" \
     "https://api.clickup.com/api/v2/team" | jq '.teams[] | {id, name}'
```

An array of workspaces means it works. Anything else is the token, not the request.

If the token reaches more than one workspace, **decide which one this folder is about and
say so at the top of the notes.** Two workspaces reachable from one token is exactly how
tasks get created in the wrong company's board.

---

## STEP 3: DISCOVER THE HIERARCHY

ClickUp nests: workspace → space → folder → list → task. Tasks are created against a **list
ID**, so list IDs are the thing worth writing down.

```bash
set -a; source .env; set +a
H="Authorization: $CLICKUP_API_TOKEN"
API="https://api.clickup.com/api/v2"

WS=<workspace_id>

# Members — assignee IDs are needed for every create and reassign
curl -s -H "$H" "$API/team" | jq '.teams[] | select(.id=="'"$WS"'") | .members[].user | {id, username, email}'

# Spaces
curl -s -H "$H" "$API/team/$WS/space" | jq '.spaces[] | {id, name}'

# Folders and their lists, per space
curl -s -H "$H" "$API/space/<space_id>/folder" \
  | jq '.folders[] | {id, name, lists: [.lists[] | {id, name}]}'

# Lists sitting at the space root, outside any folder — easy to miss
curl -s -H "$H" "$API/space/<space_id>/list" | jq '.lists[] | {id, name}'

# Statuses are per-list, not global. Check before setting one
curl -s -H "$H" "$API/list/<list_id>" | jq '.statuses[] | {status, type}'
```

---

## STEP 4: WRITE THE REFERENCE FILE

`task-board/clickup-workspace-info.md`. This is the artifact. Everything above was to
produce it.

```markdown
# ClickUp Workspace Reference — <workspace name>

> Auth: Personal API Token in `./.env` (gitignored). Header takes no `Bearer` prefix.
> Scope: this folder is about **<workspace name>** only. Other reachable workspaces: <list>.
> Discovered <date>. Refresh procedure at the bottom.

## Workspace
| | |
|---|---|
| Name | ... |
| ID | `...` |
| Base URL | `https://api.clickup.com/api/v2` |

## Members — assignee IDs
| Name | ID | Notes |
|---|---|---|
| ... | `...` | e.g. "goes by a different name in standups than in ClickUp" |

## Spaces, folders, lists
### <Space> → <Folder> — `<folder id>`
| List | ID |
|---|---|

## Endpoints in use
| Action | Method | Path |
|---|---|---|
| Tasks in a list | GET | `/list/{list_id}/task` |
| Including closed | GET | `/list/{list_id}/task?include_closed=true&subtasks=true` |
| Create task | POST | `/list/{list_id}/task` |
| Update task | PUT | `/task/{task_id}` |
| Comment | POST | `/task/{task_id}/comment` |

## Gotchas
<The most valuable section. See below.>

## Refresh
<The commands from step 3, ready to paste.>
```

**Record the naming mismatches.** If someone is called one thing in standup and another in
ClickUp, that line saves a wrong assignment later. It is exactly the kind of thing a human
knows and a fresh session cannot.

---

## STEP 5: THE GOTCHAS SECTION — this is the point

When the API fights you, the fix goes in the file, not in the conversation. A quirk
discovered twice was a note that should have been written the first time.

Two worth carrying in from the start:

**Auth header takes no `Bearer` prefix.** A Personal API Token goes in raw. Adding `Bearer`
produces an error that looks like an invalid token.

**Task creation can fail with `ITEM_246`.** `POST /list/{id}/task` returns
`{"err":"Max usage for custom task types reached","ECODE":"ITEM_246"}` when the list's
default task type points at a custom type that has hit the plan cap — every create inherits
it and fails. Pass **`"custom_item_id": 0`** explicitly to use the built-in Task type.
Assignees, tags and priority are unaffected; the block is purely the task type.

That second one is a good example of the general shape: an error message that names the
wrong cause, a fix that is one field, and a fix nobody will rediscover cheaply. Write those
down every time.

---

## WORKING RULES

The tracker is shared with humans who will not see your reasoning, only your writes.

- **Read before write, always.** Fetch the task and check its current status before updating
  it. Boards move between sessions.
- **Comment rather than overwrite.** A description someone wrote by hand is not yours to
  replace. Add a comment; edit the description only when asked.
- **Never close a task you did not verify.** "The code is merged" is not "the thing works".
  Closing is a claim, and it is the claim humans trust most.
- **Bulk operations get a dry run.** Print what would change, get a look at it, then run it.
  A loop over a list ID with an off-by-one in the filter is a very fast way to reassign
  forty tasks.
- **One workspace per folder.** If the token reaches several, the file says which one this
  is, and every script in it is scoped to that ID.
- **Statuses are per-list.** Do not assume `in progress` exists everywhere. Read the list's
  statuses before setting one.
- **Rate limits are real.** Batch reads, do not poll in a tight loop, and back off on 429
  rather than retrying immediately.

---

## AFTER

1. Verify the reference file against the board — spot-check two list IDs by fetching them.
2. Confirm `.env` is ignored: `git check-ignore -v .env`.
3. Point the workspace root `CLAUDE.md` at the file so sessions find it without being told.
4. Refresh when lists are added. A reference that has drifted is worse than none, because
   it will be trusted and the IDs will be silently wrong.

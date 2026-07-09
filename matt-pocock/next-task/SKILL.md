---
name: next-task
description: Paint a full picture of current work state, name which GSD stage we're in, and recommend the single next task. Reconstructs state from durable sources (git, the project issue tracker, PRs, repo memory, PRD/design files) — NOT conversation history — so it works when resuming across machines. Tells you whether you're at the start (nothing to do → grill me), mid-stage (/to-prd, /to-issues, /triage, /tdd), mid-slice, or blocked on a decision, and routes you to the skill that advances. The `afk` argument gates the recommended task on AFK-readiness and, if clear, lets it rip (autonomous implement+test) while honoring the project's commit/test gates. `afk delegate` additionally delegates code slices to a cheaper executor subagent (Opus) with the main-loop model overseeing: briefing, adversarial review, bounce-backs; stateful e2e slices stay in the main loop. Use when the user asks "what's next", "where are we at", "where did we leave off", "what am I working on", resumes a session on a different machine, or runs `/next-task afk`. On the `staging` branch (or `/next-task update tickets`) it sweeps all `.scratch/` features, reconciles each against its Jira status, and proposes archiving the ones Jira marks done.
---

# Next Task

Reconstruct project state from **durable sources** (git + repo files + issue tracker + PRs), not conversation history — the user switches machines, so prior conversations may be missing or stale. Treat anything in the current conversation as a hint, never the source of truth.

Two jobs:

1. **Where are we?** — Paint the picture and name the GSD lifecycle stage (start / to-prd / to-issues / triage / tdd / mid-slice / sign-off / blocked).
2. **What's next?** — Recommend ONE concrete next task and the skill that advances it. In `afk` mode, gate that task on AFK-readiness and either let it rip or name the blocker.

## Resolve config first

The issue tracker shape and triage-label vocabulary should already be provided in `docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md` — read them. They tell you whether issues live on GitHub (`gh`), GitLab (`glab`), or **local markdown** under `.scratch/<feature>/`. If those files are missing, run `/setup-matt-pocock-skills` first, then continue.

Also read the project's standing conventions before recommending or running anything — they are durable and override defaults:

- **Repo memory** — `docs/memory/MEMORY.md` if present; otherwise the in-repo auto-memory `MEMORY.md` that's already loaded into context, plus `CLAUDE.local.md`. These record commit policy, test tiers, and the e2e convention that `afk` mode MUST honor.
- **`CLAUDE.md` / `AGENTS.md`** — any "where we left off" / current-state prose.

**`.scratch/` layout + done rule** (per the `feedback-per-feature-memory` memory):

- **Two dir shapes:** feature epics are nested `.scratch/<EPIC-key>-<slug>/<TICKET-key>-<slug>/` (epic dir has an `EPIC.md`); one-offs (lone bug / KTLO / investigation) are **flat** at `.scratch/<TICKET-key>-<slug>/`. A dir with ticket subdirs = epic; a dir with `STATUS.md`/`issues/` directly = a ticket.
- **Per-ticket detail lives in `STATUS.md`** (where-we-left-off, slice→commit map, e2e results) — read it as the primary "where we left off", not chat.
- **`.scratch/archive/` is completed work — NEVER scan it.** `docs/` and `scripts/` are infrastructure, not tickets.
- **Done = Jira `statusCategory == "done"`** (Closed / Deployed / Released / Done). Anything else (To Do / In Progress / Code Review / Perpetual) = active. Fetch status live from Jira (`getJiraIssue`, fields `status`); never trust a cached status. The user override wins — flag a Jira-done ticket they say is still in progress, keep it active.

## Workflow

Run phases 1–3 in parallel, then locate the active feature (4), detect the stage (5), and synthesize (6).

### 1. Git state (local + remote)

```sh
git fetch --quiet
git status                          # uncommitted work
git branch --show-current           # branch name hints at the in-flight task
git log --oneline -10               # recent local commits
git log --oneline @{u}..HEAD        # unpushed commits (invisible to other machines)
git branch -r --sort=-committerdate # remote branches — another machine may have pushed WIP
git stash list                      # forgotten WIP
```

Flag explicitly:

- **Unpushed commits or no upstream** → "this work is invisible to your other machines."
- **Remote branch newer than local** → another machine pushed work; suggest reviewing it before starting anything.
- **Uncommitted changes** → mid-task on THIS machine; describe what the diff touches and which issue it belongs to.

### 2. Issue tracker + PRs

Read from the tracker named in `docs/agents/issue-tracker.md`.

- **Local markdown** (issues live under a ticket dir's `issues/NN-*.md`): each issue's state is the `Status:` line near the top. Scan recursively but **skip `archive/`** — e.g. `grep -rn "^Status:" .scratch --include='*.md' | grep -v '/archive/'` (catches both nested `<epic>/<ticket>/issues/` and flat `<ticket>/issues/`). Read titles (`# NN — …`) and `## Blocked by` sections. Note this repo's **terminal** state `done <date> (commit …; verification notes)` in addition to the canonical roles.
- **GitHub/GitLab**: `gh issue list --state open` / `--state closed --limit 5`, plus `gh pr list --state open`.

Regardless of where issues live, PRs are usually still on GitHub — run `gh pr list --state open` if the repo has a GitHub remote, so open PRs awaiting action surface.

Priority order for "next": ready-for-agent **bug** → ready-for-agent **enhancement** → open PR awaiting action → ready-for-human (the user's queue — list separately, don't recommend as the agent's next task).

### 3. Repo memory + plan/design

- **Memory** — read entries that look current (progress logs, "where we left off"). Cross-check memory dates against `git log` dates: memory written after the last commit is current; memory older than recent commits may be stale.
- **Plan/design** — for the active feature, read its `PRD.md` and any `design.md` / ADRs. Check the acceptance criteria and "Done when" against reality (closed issues, merged PRs, the actual code).

### 4. Locate the active feature

**On the `staging` branch (or when invoked as `/next-task update tickets`) → use Portfolio mode below instead of picking one feature.** Otherwise pick the one feature the user is most likely resuming, in this order:

1. **Branch name** — `type/APEX-####-…` maps to the ticket dir, which may be nested under an epic. Resolve it: `find .scratch -type d -name 'APEX-####*' -not -path '*/archive/*'`. This wins.
2. **Uncommitted diff / unpushed commits** — whichever feature they touch.
3. **Most recently modified** ticket dir / most recently updated open issue.

If several features are genuinely in flight, name them but anchor the report on one. Say which and why.

### 5. Detect the stage

Map the active feature's real state to a GSD lifecycle stage and the skill that advances it. Walk top-down; the first match is the stage:

| State of the active feature | Stage | Next move |
| --- | --- | --- |
| No feature/idea at all, tracker empty, nothing in flight | **Start — nothing queued** | `/grill-me` to shape what to build (or just ask the user what they want) |
| An idea/conversation exists but no PRD | **Pre-PRD** | `/to-prd` |
| PRD exists, but no issues/slices yet | **Pre-issues** | `/to-issues` |
| Issues exist but are stuck in `needs-triage` / `needs-info`, none `ready-for-agent` | **Triage** | `/triage` (or answer the open `needs-info` questions) |
| A `ready-for-agent` issue is available with blockers satisfied | **Ready to build** | `/tdd` on that slice — or `/next-task afk` to let it rip |
| Uncommitted diff / branch ahead tied to an in-progress issue | **Mid-slice** | resume that slice via `/tdd`; finish + commit before starting anything new |
| A `ready-for-human` issue is the only thing left | **Needs a human** | surface it in the user's queue; don't auto-start |
| All issues `done`/`wontfix`, PR open | **Awaiting review/merge** | address PR feedback or merge |
| All issues `done`/`wontfix`, nothing open | **Sign-off** | close out the feature, then `/to-prd` for the next one (or grill) |
| Blocked on an architectural decision / ADR conflict | **Blocked (HITL)** | `/grill-with-docs` to resolve, then continue |

When a slice is "ready to build", verify its **`## Blocked by`** entries are all `done` before recommending it. A slice blocked by an unfinished slice is NOT next — its blocker is.

### 6. Synthesize the report

```
## Where we are
- Stage: <one of the stages above>, on feature <APEX-#### / name>
- Branch / uncommitted / unpushed state (with cross-machine warnings)
- What just shipped (recent commits + recently `done` issues)
- Progress vs the PRD's acceptance / "Done when"

## In flight
- Anything mid-task (uncommitted diff, open PR, branch ahead of main)

## Next task
- ONE concrete recommendation + the skill that advances it, and why
- Runner-up only if genuinely tied

## Your human queue
- ready-for-human issues + anything blocked on a user decision

## Handoff hygiene (only if dirty)
- Unpushed/uncommitted work → remind: commit, push, update memory before switching machines
```

## Portfolio mode (on `staging`, or `/next-task update tickets`)

When there's no feature branch to anchor on (you're on `staging`), or the user explicitly asks to `update tickets`, switch from "recommend ONE" to a **portfolio sweep + Jira reconcile**. This is the ONLY place archiving is proposed — normal feature-branch `/next-task` never touches it.

1. **Enumerate live work** — `ls -d .scratch/*/` minus `archive/`, `docs/`, `scripts/`. For each, classify epic (has ticket subdirs) vs one-off (flat). The active tickets are already in `MEMORY.md`'s `## Active work` — use it as the cheap index; the `ls` is the safety net that catches orphan dirs not yet in `MEMORY.md` (surface those as "untracked — add a pointer / triage?").
2. **Reconcile against Jira** — for each tracked ticket, `getJiraIssue` (fields `status`). Bucket by `statusCategory`:
   - `done` (Closed/Deployed/Released) → **archive candidate**. Show it and **ask** "archive APEX-#### <word>?" Never auto-move. On yes: **first extract any keeper regression e2e** — if the ticket's `e2e/` holds a scenario that locks a load-bearing DB→CPL→Algolia invariant, promote it into the durable suite (`/regress add APEX-####`, → `.scratch/e2e/scenarios/`) so it outlives the archive; the ticket's own `e2e/` is throwaway. Then `mv` its dir into `.scratch/archive/…` (nested `<epic>/<ticket>` or flat for one-offs), drop its `## Active work` line in `MEMORY.md` (add to `## Archived`), and rewrite any path refs.
   - anything else → **active**; compute completion from its issue `Status:` lines and surface the next ready slice.
   - **Mismatch** (Jira `done` but the user/STATUS says in progress, or vice-versa) → flag it, default to the user's word, don't archive without confirmation.
3. **Report the portfolio** — one block per active feature: epic + ticket (with reminder word), % slices done, next ready slice, blockers. Then list archive candidates awaiting your yes/no, and any untracked orphans.
4. **Then** ask which to resume (or recommend the most-unblocked one). On `staging` it's a menu, not a single forced pick.

## AFK mode (`/next-task afk`)

Same picture as above, then **decide whether the recommended next task can run autonomously and, if so, let it rip.** AFK = an agent picks up a fully-specified slice and implements it with no human in the loop; the issue body (What to build + Acceptance criteria + Out of scope + Blocked by) is the contract.

### AFK-readiness gate — ALL must hold

- [ ] Status is `ready-for-agent` (not `ready-for-human`, `needs-info`, `needs-triage`, `wontfix`).
- [ ] The issue is a **self-contained brief**: end-to-end "what to build" + concrete, testable acceptance criteria + scope boundary. Vague criteria ("works correctly") fail the gate.
- [ ] Every `## Blocked by` entry is `done`. Otherwise the blocker is the real next task — drop to it if *it* is AFK-ready, else stop.
- [ ] No open HITL decision: no unresolved design question, no ADR conflict in the area (see `docs/adr/` and `CONTEXT.md` if present).
- [ ] Branch context is resolvable (which branch this slice lands on).

If any box fails → **do NOT start.** Report the picture, name the exact blocker, and route to the skill that unblocks: `/triage` to write/sharpen the brief, `/grill-with-docs` to resolve a decision, or "finish blocker #NN first." Then stop.

### Letting it rip — honor the project's gates

When the gate passes, drive the slice autonomously through `/tdd`, but obey the project's recorded conventions (read them in step "Resolve config first" — they are hard rules, not suggestions). For this repo they include:

- **Backend tests only** — write/run RSpec for backend; there's no frontend test suite, so verify frontend behavior manually rather than inventing JS tests.
- **Manual commits between phases** — the user reviews and commits the code themselves. So "merged without human interaction" does NOT apply here: implement + run tests autonomously, then **stop at the commit boundary** and hand back a summary for the user to review and commit. Do not auto-commit, push, or open a PR unless the user has explicitly authorized it this session.
- **Regression e2e is its own slice** — the enable→verify→disable→verify loop runs against the **local dev store** (per the project's e2e convention in memory/`CLAUDE.local.md`), never staging, and its artifacts — including any storefront **screenshots / browser captures** — live in the ticket's gitignored `e2e/` (screenshots → `e2e/screenshots/`), **never the repo root, never committed**. Don't fold it into a code slice; respect the dedicated e2e/human-verification slices when sequencing.

### Chaining (let it rip through the queue)

After a slice reaches its commit boundary, re-check the queue: if the next slice in dependency order is also AFK-ready, continue into it. Keep going until you hit a slice that fails the gate (HITL, missing brief, unsatisfied blocker) — then stop and report where the queue stalled and why. Announce the plan (the ordered list of AFK-ready slices you intend to run) before starting the first one.

### Delegated execution (`/next-task afk delegate`)

Same picture, same AFK-readiness gate, same commit boundary and chaining — but the main-loop model
does not implement code slices itself. It is the **overseer**: implementation is delegated to a
cheaper executor subagent (Agent tool, `model: "opus"`; a Workflow pipeline when chaining several
slices), and the overseer's job shifts to briefing and **reviewing**.

**Split of labor:**

- **Delegate: code slices.** The executor gets a self-contained brief — it shares no conversation
  context, so the brief must point at everything: the issue file path, the ticket `STATUS.md`, the
  relevant conventions (test-run command incl. `RAILS_ENV=test`, lint command, comment policy,
  NO commits ever), applicable ADRs/`CONTEXT.md` terms, and the branch to work on. The issue body
  is the contract; the executor implements + runs tests + lints, then returns a summary of changed
  files and test results.
- **Keep in the main loop: stateful e2e slices** (dev-store deploys, live console, Playwright
  against a real store, anything enable→verify→disable→verify). Delegation buys nothing there and
  risks permission stalls and store-state drift — the overseer runs those itself, normal afk rules.

**The review gate (the point of this mode).** After the executor reports done, the overseer
verifies independently before accepting — never take the executor's word:

1. Re-run the committed tests + lint itself.
2. Read the full diff and judge it against the issue's acceptance criteria, the area's ADRs and
   glossary vocabulary, and the repo's conventions (comment policy, patterns, no scope creep).
3. Findings → bounce back to the **same** executor (SendMessage preserves its context) with
   concrete, file-anchored findings; re-review the fix. Cap at 2 bounces — after that the overseer
   fixes the remainder itself or stops and reports.
4. Only an overseer-accepted slice counts as done: update `STATUS.md` noting executor model, review
   outcome, and bounce count, then chain to the next slice.

Plain `afk` (no `delegate`) is unchanged: the main loop implements directly. The overseer may also
judge a delegated-mode slice too trivial to be worth orchestration (a few-line fix) and do it
inline — say so in the report.

## Rules

- **Recommend ONE next task.** No menu unless two are genuinely tied — EXCEPT Portfolio mode (on `staging` or `/next-task update tickets`), which sweeps all features + proposes archives.
- **Always name the stage.** The user's first question is "where are we" — answer it before "what's next".
- **Conflicts between sources**: git history wins over memory; memory wins over `CLAUDE.md` prose; flag the conflict rather than silently picking.
- **Respect stage gates** — don't recommend issues whose blockers are unfinished; don't recommend the next feature before the current one signs off.
- **Plain mode reports, it doesn't start.** Only `afk` mode executes — and even then it stops at the project's commit boundary.

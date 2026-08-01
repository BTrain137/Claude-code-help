---
name: next-task
description: Paint a full picture of current work state, name which GSD stage we're in, and recommend the single next task. Reconstructs state from durable sources (git, GitHub issues and PRs, repo memory, PRD/design files) — NOT conversation history — so it works when resuming across machines. Tells you whether you're at the start (nothing queued → grill me), mid-stage (/to-prd, /to-issues, /triage, /tdd), mid-slice, or blocked on a decision, and routes you to the skill that advances. The `afk` argument gates the recommended task on AFK-readiness and, if clear, lets it rip (autonomous implement+test) while honoring the project's commit/test gates. `afk delegate` additionally delegates code slices to a cheaper executor subagent with the main loop overseeing: briefing, adversarial review, bounce-backs; stateful e2e slices stay in the main loop. Use when the user asks "what's next", "where are we at", "where did we leave off", resumes a session on another machine, or runs `/next-task afk`.
---

# Next Task

Reconstruct project state from **durable sources** (git + repo files + GitHub issues + PRs), not conversation history — the user switches machines, so prior conversations may be missing or stale. Treat anything in the current conversation as a hint, never the source of truth.

Two jobs:

1. **Where are we?** — Paint the picture and name the GSD lifecycle stage (start / to-prd / to-issues / triage / tdd / mid-slice / sign-off / blocked).
2. **What's next?** — Recommend ONE concrete next task and the skill that advances it. In `afk` mode, gate that task on AFK-readiness and either let it rip or name the blocker.

## Resolve config first

Issues live on **GitHub**, read via the `gh` CLI. `docs/agents/issue-tracker.md` names the repo slug (it normally infers it from the git remote) and `docs/agents/triage-labels.md` gives the triage-label vocabulary — read both. If they're missing, run `/setup-matt-pocock-skills` first, then continue.

Also read the project's standing conventions before recommending or running anything — they are durable and override defaults:

- **Repo memory** — `docs/memory/MEMORY.md` if present; otherwise the in-repo auto-memory `MEMORY.md` already loaded into context, plus `CLAUDE.local.md`. These record commit policy, test tiers, and the e2e convention that `afk` mode MUST honor.
- **`CLAUDE.md` / `AGENTS.md`** — any "where we left off" / current-state prose.

**Where "where we left off" lives:** the issue itself. `gh issue view <N> --comments` — the slice→commit map, test results, and blockers get recorded as comments on the issue. Read those as the primary handoff note, not chat. A milestone (or an epic/tracking issue with a task list) groups the slices of one feature.

**Done = the issue is closed.** Anything open — regardless of labels — is active. The user's word overrides: if they say a closed issue is still in progress, flag the mismatch and treat it as active.

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

### 2. Issues + PRs

```sh
gh issue list --state open --json number,title,labels,milestone,updatedAt
gh issue list --state closed --limit 5          # what just shipped
gh pr list --state open --json number,title,headRefName,isDraft,reviewDecision
```

Read the bodies of the candidates (`gh issue view <N>`) for **What to build / Acceptance criteria / Out of scope / Blocked by**. A `## Blocked by` section referencing `#NN` is a hard dependency — resolve each referenced issue's state before treating the slice as available.

Priority order for "next": ready-for-agent **bug** → ready-for-agent **enhancement** → open PR awaiting action → ready-for-human (the user's queue — list separately, don't recommend as the agent's next task).

### 3. Repo memory + plan/design

- **Memory** — read entries that look current (progress logs, "where we left off"). Cross-check memory dates against `git log` dates: memory written after the last commit is current; memory older than recent commits may be stale.
- **Plan/design** — for the active feature, read its PRD (often the milestone description or a tracking issue) and any `design.md` / ADRs in `docs/adr/`. Check the acceptance criteria and "Done when" against reality (closed issues, merged PRs, the actual code).

### 3a. Maintenance reminders (time-based, only if the file exists)

Skip this step entirely in projects that don't have these files — don't report their absence.

- **`docs/op-token-expiry.txt`** — the 1Password AFK service-account token's `EXPIRES=` date. Compute days remaining vs today:
  - **past** → flag loudly: "⚠️ AFK token EXPIRED — rotate and update `docs/op-token-expiry.txt`" (rotation steps are in that file + the secrets ADR; `/onboard` covers it).
  - **within ~14 days** → "AFK token expires soon (DATE) — rotate before then."
  - **otherwise** → stay quiet; don't clutter the report.

  After rotating, the user updates the dates in that file. The `onboard` skill's setup checker computes the same thing.

### 4. Locate the active feature

**On the default branch (`main`) with nothing in flight, or when invoked as `/next-task update tickets` → use Portfolio mode below instead of picking one feature.** Otherwise pick the one feature the user is most likely resuming, in this order:

1. **Branch name** — `type/123-slug` maps to issue `#123`; resolve it with `gh issue view 123`. This wins.
2. **Uncommitted diff / unpushed commits** — whichever issue they touch. Cross-reference `#NN` mentions in recent commit messages.
3. **Most recently updated** open issue or milestone.

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
| All issues closed or `wontfix`, PR open | **Awaiting review/merge** | address PR feedback or merge |
| All issues closed or `wontfix`, nothing open | **Sign-off** | close out the milestone, then `/to-prd` for the next feature (or grill) |
| Blocked on an architectural decision / ADR conflict | **Blocked (HITL)** | `/grill-with-docs` to resolve, then continue |

When a slice is "ready to build", verify its **`## Blocked by`** issues are all closed before recommending it. A slice blocked by an unfinished slice is NOT next — its blocker is.

### 6. Synthesize the report

```
## Where we are
- Stage: <one of the stages above>, on feature <milestone / #NN / name>
- Branch / uncommitted / unpushed state (with cross-machine warnings)
- What just shipped (recent commits + recently closed issues)
- Progress vs the PRD's acceptance / "Done when"

## In flight
- Anything mid-task (uncommitted diff, open PR, branch ahead of main)

## Next task
- ONE concrete recommendation + the skill that advances it, and why
- Runner-up only if genuinely tied

## Your human queue
- ready-for-human issues + anything blocked on a user decision

## Maintenance (only if due)
- AFK token expiry within 14 days / passed (docs/op-token-expiry.txt) → rotate + update the date

## Handoff hygiene (only if dirty)
- Unpushed/uncommitted work → remind: commit, push, update memory before switching machines
```

## Portfolio mode (on `main` with nothing in flight, or `/next-task update tickets`)

When there's no feature branch to anchor on, or the user explicitly asks to `update tickets`, switch from "recommend ONE" to a **portfolio sweep + tracker reconcile**. This is the ONLY place issue-closing is proposed — normal feature-branch `/next-task` never touches issue state.

1. **Enumerate live work** — `gh issue list --state open` grouped by milestone. Issues with no milestone are their own bucket; surface them as "untracked — assign a milestone / triage?". Cross-check against `MEMORY.md`'s active-work notes: memory is the cheap index, the `gh` list is the safety net that catches issues memory doesn't know about.
2. **Reconcile against git** — for each open issue, check whether the work actually landed: `git log --oneline --grep "#<N>"` and `gh pr list --state merged --search "<N>"`. Bucket:
   - **Work landed but the issue is still open** → **close candidate.** Show it and **ask** "close #NN <title>?" Never auto-close. On yes: `gh issue close <N> --comment "<the commit/PR that closed it>"`, and update the corresponding `MEMORY.md` line.
   - **Genuinely open** → **active**; compute completion from the milestone's closed/total, and surface the next ready slice.
   - **Mismatch** (git says done but the user says in progress, or an issue closed with no matching commit) → flag it, default to the user's word, don't close without confirmation.
3. **Report the portfolio** — one block per active milestone: name, % slices closed, next ready slice, blockers. Then list close candidates awaiting your yes/no, and any milestone-less orphans.
4. **Then** ask which to resume (or recommend the most-unblocked one). In Portfolio mode it's a menu, not a single forced pick.

## AFK mode (`/next-task afk`)

Same picture as above, then **decide whether the recommended next task can run autonomously and, if so, let it rip.** AFK = an agent picks up a fully-specified slice and implements it with no human in the loop; the issue body (What to build + Acceptance criteria + Out of scope + Blocked by) is the contract.

### AFK-readiness gate — ALL must hold

- [ ] Labeled `ready-for-agent` (not `ready-for-human`, `needs-info`, `needs-triage`, `wontfix`).
- [ ] The issue is a **self-contained brief**: end-to-end "what to build" + concrete, testable acceptance criteria + scope boundary. Vague criteria ("works correctly") fail the gate.
- [ ] Every `## Blocked by` issue is closed. Otherwise the blocker is the real next task — drop to it if *it* is AFK-ready, else stop.
- [ ] No open HITL decision: no unresolved design question, no ADR conflict in the area (see `docs/adr/` and `CONTEXT.md` if present).
- [ ] Branch context is resolvable (which branch this slice lands on).

If any box fails → **do NOT start.** Report the picture, name the exact blocker, and route to the skill that unblocks: `/triage` to write/sharpen the brief, `/grill-with-docs` to resolve a decision, or "finish blocker #NN first." Then stop.

### Letting it rip — honor the project's gates

When the gate passes, drive the slice autonomously through `/tdd`, but obey the project's recorded conventions (read them in "Resolve config first" — they are hard rules, not suggestions). Typically they include:

- **The project's own test tiers** — run the suites the repo actually defines, with the repo's own commands. Don't invent a test layer the project doesn't have; where there's no automated suite for a surface, verify it manually and say so.
- **Commit policy** — most of these projects want the user to review and commit themselves. Unless the repo's memory or `CLAUDE.md` explicitly authorizes it, implement + run tests autonomously, then **stop at the commit boundary** and hand back a summary. Do not auto-commit, push, or open a PR without explicit authorization this session.
- **Regression e2e is its own slice** — where the project records an e2e convention, follow it exactly rather than folding e2e into a code slice. The common shape here is **bidirectional**: turn the feature ON → exercise it + verify it's configured → turn it OFF → verify everything still works, asserting real state at each transition, with cleanup itself asserted. Its artifacts (screenshots, captures) go wherever the project puts gitignored test output — never the repo root, never committed. Respect dedicated e2e/human-verification slices when sequencing.

### Chaining (let it rip through the queue)

After a slice reaches its commit boundary, re-check the queue: if the next slice in dependency order is also AFK-ready, continue into it. Keep going until you hit a slice that fails the gate (HITL, missing brief, unsatisfied blocker) — then stop and report where the queue stalled and why. Announce the plan (the ordered list of AFK-ready slices you intend to run) before starting the first one.

### Delegated execution (`/next-task afk delegate`)

Same picture, same AFK-readiness gate, same commit boundary and chaining — but the main-loop model
does not implement code slices itself. It is the **overseer**: implementation is delegated to a
cheaper executor subagent (Agent tool; a Workflow pipeline when chaining several slices), and the
overseer's job shifts to briefing and **reviewing**.

**Split of labor:**

- **Delegate: code slices.** The executor gets a self-contained brief — it shares no conversation
  context, so the brief must point at everything: the issue number and its body, the relevant
  conventions (the repo's exact test-run and lint commands, comment policy, NO commits ever),
  applicable ADRs/`CONTEXT.md` terms, and the branch to work on. The issue body is the contract; the
  executor implements + runs tests + lints, then returns a summary of changed files and test results.
- **Keep in the main loop: stateful e2e slices** (live deploys, real-store state, browser drives,
  anything enable→verify→disable→verify). Delegation buys nothing there and risks permission stalls
  and state drift — the overseer runs those itself, normal afk rules.

**The review gate (the point of this mode).** After the executor reports done, the overseer
verifies independently before accepting — never take the executor's word:

1. Re-run the tests + lint itself.
2. Read the full diff and judge it against the issue's acceptance criteria, the area's ADRs and
   glossary vocabulary, and the repo's conventions (comment policy, patterns, no scope creep).
3. Findings → bounce back to the **same** executor (SendMessage preserves its context) with
   concrete, file-anchored findings; re-review the fix. Cap at 2 bounces — after that the overseer
   fixes the remainder itself or stops and reports.
4. Only an overseer-accepted slice counts as done: comment the outcome on the issue (executor model,
   review outcome, bounce count), then chain to the next slice.

Plain `afk` (no `delegate`) is unchanged: the main loop implements directly. The overseer may also
judge a delegated-mode slice too trivial to be worth orchestration (a few-line fix) and do it
inline — say so in the report.

## Rules

- **Recommend ONE next task.** No menu unless two are genuinely tied — EXCEPT Portfolio mode, which sweeps all features + proposes issue closes.
- **Always name the stage.** The user's first question is "where are we" — answer it before "what's next".
- **Conflicts between sources**: git history wins over memory; memory wins over `CLAUDE.md` prose; flag the conflict rather than silently picking.
- **Respect stage gates** — don't recommend issues whose blockers are unfinished; don't recommend the next feature before the current one signs off.
- **Plain mode reports, it doesn't start.** Only `afk` mode executes — and even then it stops at the project's commit boundary.

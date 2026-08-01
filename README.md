# Claude Code Help

A collection of guides, tools, and workflows for working with Claude Code.

## Guides

- **[Claude Code Statusline Setup](CLAUDE_CODE_STATUSLINE_SETUP.md)** -- Custom statusline showing context window usage, daily token/cost tracking, git branch, and a color-coded progress bar.

## Skills

Extensions of [mattpocock/skills](https://github.com/mattpocock/skills), under `matt-pocock/`.

**next-task** -- Reconstructs project state from durable sources (git, issues/PRs, in-repo memory, plan files) rather than conversation history, names the GSD lifecycle stage, and recommends the single next task. Built for resuming work across machines where conversation history is unreliable. Two variants, forked by issue tracker -- pick one per project; both declare `name: next-task`, so either installs as `/next-task`.

| Variant | Use when | Tracker | "Where we left off" lives in |
| --- | --- | --- | --- |
| **[next-task-github](matt-pocock/next-task-github/SKILL.md)** | Personal projects | GitHub Issues via `gh` | issue comments |
| **[next-task-jira](matt-pocock/next-task-jira/SKILL.md)** | Work machine | Jira + local markdown | `.scratch/<epic>/<ticket>/STATUS.md` |

The Jira variant exists because that machine can't commit working files to the shared repo, so tickets live in a gitignored `.scratch/` tree. It also hardcodes that project's stack (RSpec/Rails, `staging` branch). The GitHub variant is the general-purpose one: no `.scratch/`, done means the issue is closed, and its portfolio sweep reconciles open issues against git history instead of archiving directories.

Both support `/next-task afk` (gate the next slice on AFK-readiness, then implement + test autonomously up to the commit boundary) and `/next-task afk delegate` (delegate code slices to a cheaper executor subagent, main loop reviews).

**Install:** copy the chosen variant's folder into a project's `.claude/skills/` (rename it to `next-task/`), or into `~/.agents/skills/` with a symlink from `~/.claude/skills/` to install it globally.

## BMAD Workflows

- **[Auto-Sprint](bmad-auto-sprint/)** -- Autonomous sprint loop that cycles through Create Story → Dev Story → Quality Gate → Code Review until scope is complete. Ralph-style YOLO execution with circuit breakers.

## Speckit Workflows
- is a structured ideation-to-implementation pipeline implemented as 15 slash commands for Claude Code. It turns vague feature ideas into formal specs, plans, tasks, and working code.

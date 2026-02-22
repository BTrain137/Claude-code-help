## Speckit -- Feature Development Workflow

**Speckit** is a structured ideation-to-implementation pipeline implemented as 15 slash commands for Claude Code. It turns vague feature ideas into formal specs, plans, tasks, and working code.

```
Ideate → Specify → Clarify → Plan → Tasks → Analyze → Checklist → Triage → Preflight → Implement
```

### Quick Install

Run this in your project root:

```bash
TMPDIR=$(mktemp -d) && \
git clone --depth 1 https://github.com/BTrain137/Claude-code-help.git "$TMPDIR" && \
mkdir -p .claude/commands .specify/templates .specify/scripts/bash .specify/memory speckit-helpers && \
cp "$TMPDIR/speckit/commands/"*.md .claude/commands/ && \
cp "$TMPDIR/speckit/specify/templates/"*.md .specify/templates/ && \
cp "$TMPDIR/speckit/specify/scripts/bash/"*.sh .specify/scripts/bash/ && \
cp "$TMPDIR/speckit/specify/memory/constitution.md" .specify/memory/ && \
chmod +x .specify/scripts/bash/*.sh && \
rm -rf "$TMPDIR" && \
echo "Speckit installed successfully!"
```

### What You Get

| Command | Purpose |
|---------|---------|
| `/01-speckit.ideate` | Brainstorm a feature interactively |
| `/02-speckit.specify` | Create a formal spec.md |
| `/03-speckit.clarify` | Fill in ambiguities |
| `/05-speckit.plan` | Generate implementation plan |
| `/06-speckit.tasks` | Break into ordered tasks |
| `/11-speckit.implement` | Build it from tasks.md |

...plus 9 more commands for constitution, analysis, checklists, triage, preflight, sync, checkpoints, and GitHub issue creation.

### Full Documentation

See **[speckit/SKILL.md](speckit/SKILL.md)** for the complete command reference, detailed install instructions (including curl-based install), workflow guides, and post-install setup.

## Speckit -- Feature Development Workflow

### LLM Install

If you're using Claude Code or any LLM assistant, point it at the SKILL.md:

> Read https://github.com/BTrain137/Claude-code-help/blob/main/speckit/SKILL.md and install speckit in this project.

The SKILL.md contains everything an LLM needs to set up speckit from scratch.

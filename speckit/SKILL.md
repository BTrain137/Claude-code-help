# Speckit -- Install Skill

Use this skill when a user wants to add speckit to their project, set up the speckit workflow, or asks about speckit slash commands. Also trigger when the user mentions "speckit," "install speckit," "add speckit," "set up speckit," "feature workflow," or "ideation to implementation pipeline."

## What Is Speckit?

Speckit is a structured feature development workflow implemented as slash commands for Claude Code (and compatible with Cursor via symlinks). It provides a complete pipeline from **ideation to implementation**:

```
Ideate → Specify → Clarify → Plan → Tasks → Analyze → Checklist → Triage → Preflight → Implement
```

Each step is a standalone slash command that reads/writes artifacts in a `specs/` directory, with supporting templates and scripts in `.specify/`.

## Commands Overview

Run these in order. Each command is a markdown file placed in `.claude/commands/`.

| #  | Command                         | Slash Usage              | Purpose                                             |
|----|---------------------------------|--------------------------|-----------------------------------------------------|
| 00 | `00-speckit.constitution.md`    | `/00-speckit.constitution` | Create/update project constitution (principles)    |
| 01 | `01-speckit.ideate.md`          | `/01-speckit.ideate`       | Interactive feature discovery conversation         |
| 02 | `02-speckit.specify.md`         | `/02-speckit.specify`      | Create formal feature specification (spec.md)      |
| 03 | `03-speckit.clarify.md`         | `/03-speckit.clarify`      | Identify ambiguities and ask clarifying questions  |
| 04 | `04-speckit.planit.md`          | `/04-speckit.planit`       | Interactive implementation planning conversation   |
| 05 | `05-speckit.plan.md`            | `/05-speckit.plan`         | Generate plan artifacts (plan.md, data-model, etc) |
| 06 | `06-speckit.tasks.md`           | `/06-speckit.tasks`        | Break plan into dependency-ordered tasks.md        |
| 07 | `07-speckit.analyze.md`         | `/07-speckit.analyze`      | Cross-artifact consistency and quality analysis    |
| 08 | `08-speckit.checklist.md`       | `/08-speckit.checklist`    | Generate requirements quality checklist            |
| 09 | `09-speckit.triage.md`          | `/09-speckit.triage`       | Triage checklist items and remediate gaps           |
| 10 | `10-speckit.preflight.md`       | `/10-speckit.preflight`    | Pre-implementation blocker scan                    |
| 11 | `11-speckit.implement.md`       | `/11-speckit.implement`    | Execute implementation from tasks.md               |
| 12 | `12-speckit.sync.md`            | `/12-speckit.sync`         | Sync features.yaml and CLAUDE.md feature history   |
| -- | `speckit.checkpoint.md`         | `/speckit.checkpoint`      | Validate checkpoint criteria during implementation |
| -- | `speckit.taskstoissues.md`      | `/speckit.taskstoissues`   | Convert tasks.md into GitHub issues                |

## Typical Workflow

**Quick path (for most features):**
1. `/01-speckit.ideate` -- brainstorm the feature
2. `/02-speckit.specify` -- formalize into spec.md
3. `/03-speckit.clarify` -- fill in gaps
4. `/05-speckit.plan` -- create implementation plan
5. `/06-speckit.tasks` -- generate tasks.md
6. `/11-speckit.implement` -- build it

**Full path (for complex features):**
1. `/00-speckit.constitution` -- set up project principles (once per project)
2. `/01-speckit.ideate` -- brainstorm the feature
3. `/02-speckit.specify` -- formalize into spec.md
4. `/03-speckit.clarify` -- fill in gaps
5. `/04-speckit.planit` -- interactive planning conversation
6. `/05-speckit.plan` -- generate plan artifacts
7. `/06-speckit.tasks` -- generate tasks.md
8. `/07-speckit.analyze` -- check consistency across all artifacts
9. `/08-speckit.checklist` -- generate quality checklist
10. `/09-speckit.triage` -- resolve checklist items
11. `/10-speckit.preflight` -- check for blockers (API keys, credentials, etc.)
12. `/11-speckit.implement` -- build it
13. `/12-speckit.sync` -- update feature tracking

## Installation Instructions

### Source Repository

All files are hosted at:
```
https://github.com/BTrain137/Claude-code-help/tree/main/speckit
```

### Raw File Base URL

```
https://raw.githubusercontent.com/BTrain137/Claude-code-help/main/speckit
```

### Step 1: Install Slash Commands

Create `.claude/commands/` in the target project root and download all 15 command files:

```bash
mkdir -p .claude/commands

REPO_RAW="https://raw.githubusercontent.com/BTrain137/Claude-code-help/main/speckit"

# Core workflow commands (numbered)
curl -sL "$REPO_RAW/commands/00-speckit.constitution.md" -o .claude/commands/00-speckit.constitution.md
curl -sL "$REPO_RAW/commands/01-speckit.ideate.md"       -o .claude/commands/01-speckit.ideate.md
curl -sL "$REPO_RAW/commands/02-speckit.specify.md"      -o .claude/commands/02-speckit.specify.md
curl -sL "$REPO_RAW/commands/03-speckit.clarify.md"      -o .claude/commands/03-speckit.clarify.md
curl -sL "$REPO_RAW/commands/04-speckit.planit.md"       -o .claude/commands/04-speckit.planit.md
curl -sL "$REPO_RAW/commands/05-speckit.plan.md"         -o .claude/commands/05-speckit.plan.md
curl -sL "$REPO_RAW/commands/06-speckit.tasks.md"        -o .claude/commands/06-speckit.tasks.md
curl -sL "$REPO_RAW/commands/07-speckit.analyze.md"      -o .claude/commands/07-speckit.analyze.md
curl -sL "$REPO_RAW/commands/08-speckit.checklist.md"    -o .claude/commands/08-speckit.checklist.md
curl -sL "$REPO_RAW/commands/09-speckit.triage.md"       -o .claude/commands/09-speckit.triage.md
curl -sL "$REPO_RAW/commands/10-speckit.preflight.md"    -o .claude/commands/10-speckit.preflight.md
curl -sL "$REPO_RAW/commands/11-speckit.implement.md"    -o .claude/commands/11-speckit.implement.md
curl -sL "$REPO_RAW/commands/12-speckit.sync.md"         -o .claude/commands/12-speckit.sync.md

# Utility commands (unnumbered)
curl -sL "$REPO_RAW/commands/speckit.checkpoint.md"      -o .claude/commands/speckit.checkpoint.md
curl -sL "$REPO_RAW/commands/speckit.taskstoissues.md"   -o .claude/commands/speckit.taskstoissues.md
```

### Step 2: Install Supporting Files

The commands depend on templates, bash scripts, and a constitution template in `.specify/`. Install them:

```bash
# Templates
mkdir -p .specify/templates
curl -sL "$REPO_RAW/specify/templates/spec-template.md"       -o .specify/templates/spec-template.md
curl -sL "$REPO_RAW/specify/templates/plan-template.md"       -o .specify/templates/plan-template.md
curl -sL "$REPO_RAW/specify/templates/tasks-template.md"      -o .specify/templates/tasks-template.md
curl -sL "$REPO_RAW/specify/templates/checklist-template.md"  -o .specify/templates/checklist-template.md
curl -sL "$REPO_RAW/specify/templates/agent-file-template.md" -o .specify/templates/agent-file-template.md

# Bash scripts
mkdir -p .specify/scripts/bash
curl -sL "$REPO_RAW/specify/scripts/bash/common.sh"               -o .specify/scripts/bash/common.sh
curl -sL "$REPO_RAW/specify/scripts/bash/check-prerequisites.sh"  -o .specify/scripts/bash/check-prerequisites.sh
curl -sL "$REPO_RAW/specify/scripts/bash/create-new-feature.sh"   -o .specify/scripts/bash/create-new-feature.sh
curl -sL "$REPO_RAW/specify/scripts/bash/setup-plan.sh"           -o .specify/scripts/bash/setup-plan.sh
curl -sL "$REPO_RAW/specify/scripts/bash/update-agent-context.sh" -o .specify/scripts/bash/update-agent-context.sh
chmod +x .specify/scripts/bash/*.sh

# Constitution template
mkdir -p .specify/memory
curl -sL "$REPO_RAW/specify/memory/constitution.md" -o .specify/memory/constitution.md
```

### Step 3: Create Feature Helpers Directory

Commands store ideation and planning documents here:

```bash
mkdir -p speckit-helpers
```

### Step 4: Verify Installation

Confirm the file structure:

```bash
echo "=== Slash Commands ==="
ls .claude/commands/*speckit* 2>/dev/null | wc -l
echo "files in .claude/commands/"

echo "=== Templates ==="
ls .specify/templates/*.md 2>/dev/null | wc -l
echo "files in .specify/templates/"

echo "=== Scripts ==="
ls .specify/scripts/bash/*.sh 2>/dev/null | wc -l
echo "files in .specify/scripts/bash/"

echo "=== Constitution ==="
ls .specify/memory/constitution.md 2>/dev/null && echo "OK" || echo "MISSING"
```

Expected: 15 commands, 5 templates, 5 scripts, 1 constitution file.

### One-Liner Install (Alternative)

If `git` is available, clone the repo and copy files in one shot:

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

## Post-Install: Getting Started

1. **Set up your constitution** (recommended first step):
   ```
   /00-speckit.constitution
   ```
   This fills in the project principles template at `.specify/memory/constitution.md`.

2. **Start your first feature**:
   ```
   /01-speckit.ideate Add user authentication with OAuth
   ```

3. **Follow the workflow** through specify, plan, tasks, and implement.

## File Structure After Installation

```
your-project/
├── .claude/
│   └── commands/
│       ├── 00-speckit.constitution.md
│       ├── 01-speckit.ideate.md
│       ├── 02-speckit.specify.md
│       ├── ... (15 files total)
│       └── speckit.taskstoissues.md
├── .specify/
│   ├── templates/
│   │   ├── spec-template.md
│   │   ├── plan-template.md
│   │   ├── tasks-template.md
│   │   ├── checklist-template.md
│   │   └── agent-file-template.md
│   ├── scripts/bash/
│   │   ├── common.sh
│   │   ├── check-prerequisites.sh
│   │   ├── create-new-feature.sh
│   │   ├── setup-plan.sh
│   │   └── update-agent-context.sh
│   └── memory/
│       └── constitution.md
├── speckit-helpers/          (created per feature, not tracked in speckit repo)
│   └── 001-feature-name/
│       ├── 01-feature-name.md
│       └── 02-speckit-plan-feature-name.md
└── specs/                    (created per feature by the commands)
    └── 001-feature-name/
        ├── spec.md
        ├── plan.md
        └── tasks.md
```

## Compatibility

- **Claude Code**: Native support -- commands appear as `/00-speckit.ideate`, etc.
- **Cursor**: Symlink `.claude/commands/` to Cursor's command location, or use Claude Code directly.
- **Any LLM**: The command files are plain markdown. An LLM can read and follow the instructions in any file directly.

## Updating

To update speckit to the latest version, re-run the installation commands. They will overwrite existing files with the latest versions from the repository.

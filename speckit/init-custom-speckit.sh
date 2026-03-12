#!/usr/bin/env bash
# init-custom-speckit.sh — One-shot setup for spec-kit + ai-context-library
# Run from any project root: ~/bin/init-custom-speckit.sh
# Idempotent — safe to re-run to update to latest versions.

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────────────────
SPECKIT_REPO="https://github.com/BTrain137/Claude-code-help.git"
SPECKIT_SUBPATH="speckit"
AICL_REPO="https://github.com/BTrain137/ai-context-library.git"
BRANCH="main"

# ─── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$1"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
err()   { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

# ─── Cleanup trap ────────────────────────────────────────────────────────────
TEMP_SPECKIT=""
TEMP_AICL=""
cleanup() {
    [[ -n "$TEMP_SPECKIT" && -d "$TEMP_SPECKIT" ]] && rm -rf "$TEMP_SPECKIT"
    [[ -n "$TEMP_AICL" && -d "$TEMP_AICL" ]] && rm -rf "$TEMP_AICL"
}
trap cleanup EXIT

# ─── Phase 0: Install spec-kit via uvx ───────────────────────────────────────
phase0_install_speckit() {
    info "Phase 0: Installing spec-kit framework"

    if ! command -v uvx &>/dev/null; then
        err "uvx not found. Install it first:"
        err "  pip install uv"
        err "  # or: brew install uv"
        exit 1
    fi

    if [[ -d ".specify" ]]; then
        printf "${YELLOW}[WARN]${NC}  .specify/ already exists. Re-run 'specify init'? [y/N] "
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            info "Re-running specify init..."
            uvx --from "git+https://github.com/github/spec-kit.git" specify init . --ai claude
            ok "spec-kit re-initialized"
        else
            info "Skipping spec-kit init (keeping existing .specify/)"
        fi
    else
        uvx --from "git+https://github.com/github/spec-kit.git" specify init . --ai claude
        ok "spec-kit installed"
    fi
}

# ─── Phase 1: Validate prerequisites ─────────────────────────────────────────
phase1_validate() {
    info "Phase 1: Validating prerequisites"

    if ! command -v git &>/dev/null; then
        err "git is not installed"
        exit 1
    fi

    # Quick network check
    if ! git ls-remote "$SPECKIT_REPO" HEAD &>/dev/null; then
        err "Cannot reach $SPECKIT_REPO — check your network"
        exit 1
    fi

    ok "Prerequisites validated"
}

# ─── Phase 2: Create directories ─────────────────────────────────────────────
phase2_create_dirs() {
    info "Phase 2: Creating directories"

    mkdir -p .library/commands/speckit
    mkdir -p .library/commands/project
    mkdir -p .library/skills/project
    mkdir -p .specify/templates
    mkdir -p .specify/scripts/bash
    mkdir -p .claude/commands
    mkdir -p .claude/skills
    mkdir -p scripts

    ok "Directories created"
}

# ─── Phase 3: Clone repos ────────────────────────────────────────────────────
phase3_clone() {
    info "Phase 3: Cloning source repos (shallow)"

    TEMP_SPECKIT=$(mktemp -d)
    git clone --depth 1 --branch "$BRANCH" "$SPECKIT_REPO" "$TEMP_SPECKIT" 2>/dev/null
    ok "Cloned Claude-code-help → $TEMP_SPECKIT"

    TEMP_AICL=$(mktemp -d)
    git clone --depth 1 --branch "$BRANCH" "$AICL_REPO" "$TEMP_AICL" 2>/dev/null
    ok "Cloned ai-context-library → $TEMP_AICL"
}

# ─── Phase 4: Copy speckit files ─────────────────────────────────────────────
phase4_copy_speckit() {
    info "Phase 4: Copying speckit files"
    local src="$TEMP_SPECKIT/$SPECKIT_SUBPATH"

    # Commands (15 .md files)
    local cmd_count=0
    for f in "$src"/commands/*.md; do
        [[ -f "$f" ]] || continue
        cp "$f" .library/commands/speckit/
        cmd_count=$((cmd_count + 1))
    done
    ok "Copied $cmd_count speckit commands → .library/commands/speckit/"

    # Templates (5 .md files)
    local tmpl_count=0
    for f in "$src"/specify/templates/*.md; do
        [[ -f "$f" ]] || continue
        cp "$f" .specify/templates/
        tmpl_count=$((tmpl_count + 1))
    done
    ok "Copied $tmpl_count templates → .specify/templates/"

    # Scripts (5 .sh files)
    local script_count=0
    for f in "$src"/specify/scripts/bash/*.sh; do
        [[ -f "$f" ]] || continue
        cp "$f" .specify/scripts/bash/
        script_count=$((script_count + 1))
    done
    ok "Copied $script_count scripts → .specify/scripts/bash/"
}

# ─── Phase 5: Copy ai-context-library files ──────────────────────────────────
phase5_copy_aicl() {
    info "Phase 5: Copying ai-context-library files"
    local src="$TEMP_AICL"

    # Scripts (4 .sh files)
    cp "$src/scripts/toggle-commands.sh"  scripts/toggle-commands.sh
    cp "$src/scripts/toggle-skills.sh"    scripts/toggle-skills.sh
    cp "$src/scripts/organize-library.sh" scripts/organize-library.sh
    cp "$src/scripts/import-repo.sh"      scripts/import-repo.sh
    ok "Copied 4 scripts → scripts/"

    # Command templates
    cp "$src/templates/toggle-commands.md"  .library/commands/project/toggle-commands.md
    cp "$src/templates/organize-library.md" .library/commands/project/organize-library.md
    cp "$src/templates/import-repo.md"      .library/commands/project/import-repo.md
    ok "Copied 3 command templates → .library/commands/project/"

    # Organize-library skill
    mkdir -p .library/skills/project/organize-library/references
    cp "$src/templates/organize-library-skill/SKILL.md" \
       .library/skills/project/organize-library/SKILL.md
    cp "$src/templates/organize-library-skill/references/library-structure.md" \
       .library/skills/project/organize-library/references/library-structure.md
    ok "Copied organize-library skill → .library/skills/project/organize-library/"
}

# ─── Phase 6: Generate generic toggle-skills.md ──────────────────────────────
phase6_generate_toggle_skills() {
    info "Phase 6: Generating generic toggle-skills.md"

    cat > .library/commands/project/toggle-skills.md << 'TOGGLE_EOF'
---
description: Toggle skill groups on or off, or list current status.
---

# Toggle Skills

Enable or disable skill groups independently.

## Instructions

Check the user's argument to determine the action:

**User input**: `$ARGUMENTS`

### If argument is "on" followed by a group name (e.g., "on my-group"):

```bash
bash scripts/toggle-skills.sh <group> on
```

Tell the user:
> <group> skills enabled. Restart Claude Code or run `/clear` for changes to take effect.

### If argument is "off" followed by a group name (e.g., "off my-group"):

```bash
bash scripts/toggle-skills.sh <group> off
```

Tell the user:
> <group> skills disabled. Restart Claude Code or run `/clear` for changes to take effect.

### If argument is "list" (or empty/missing):

```bash
bash scripts/toggle-skills.sh list
```
TOGGLE_EOF

    ok "Generated generic toggle-skills.md → .library/commands/project/"
}

# ─── Phase 7: Post-install ───────────────────────────────────────────────────
phase7_post_install() {
    info "Phase 7: Post-install configuration"

    # Make all .sh files executable
    find scripts/ -name "*.sh" -exec chmod +x {} \;
    find .specify/scripts/ -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    ok "Made all .sh files executable"

    # Update .gitignore (idempotent)
    local gitignore_entries=(
        ".claude/commands/"
        ".claude/skills/"
        ".specstory/**"
        ".DS_Store"
        "._*"
    )
    touch .gitignore
    for entry in "${gitignore_entries[@]}"; do
        if ! grep -qxF "$entry" .gitignore; then
            echo "$entry" >> .gitignore
            info "Added '$entry' to .gitignore"
        fi
    done
    ok "Gitignore updated"

    # Clean macOS resource fork files
    if command -v dot_clean &>/dev/null; then
        dot_clean . 2>/dev/null || true
    fi
    find . -name "._*" -not -path "./.git/*" -delete 2>/dev/null || true
    ok "Cleaned resource fork files"

    # Git: remove tracked symlink dirs from index (if in a git repo)
    if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
        git rm -r --cached .claude/commands/ 2>/dev/null || true
        git rm -r --cached .claude/skills/ 2>/dev/null || true
        ok "Ensured .claude/ dirs are untracked"
    else
        warn "Not a git repo — skipping git rm --cached"
    fi

    # Bootstrap symlinks: enable project + speckit command groups, project skill group
    info "Bootstrapping symlinks..."
    bash scripts/toggle-commands.sh project on
    bash scripts/toggle-commands.sh speckit on
    bash scripts/toggle-skills.sh project on
    ok "Symlinks bootstrapped (project commands ON, speckit commands ON, project skills ON)"

    # Create or append CLAUDE.md
    local marker="## AI Context Library"
    if [[ ! -f CLAUDE.md ]]; then
        cat > CLAUDE.md << 'CLAUDEMD_EOF'
# Project Name

Brief description of your project.

## AI Context Library

This project uses the **ai-context-library** pattern: `.library/` is the git-tracked source of truth, and `.claude/commands/` + `.claude/skills/` contain only symlinks managed by toggle scripts.

### Key Commands

- `/toggle-commands` — Enable/disable command groups
- `/toggle-skills` — Enable/disable skill groups
- `/organize-library` — Detect and organize files dropped into `.claude/`
- `/import-repo` — Import skills/commands from a GitHub repository

### Quick Reference

```bash
bash scripts/toggle-commands.sh list        # Show command group status
bash scripts/toggle-skills.sh list          # Show skill group status
bash scripts/organize-library.sh scan       # Find unorganized files
```

## Notes

- ExFAT drive: macOS creates `._*` resource fork files — the toggle scripts clean these automatically.
- Scripts assume they're run from the repo root.
CLAUDEMD_EOF
        ok "Created CLAUDE.md"
    elif ! grep -qF "$marker" CLAUDE.md; then
        cat >> CLAUDE.md << 'CLAUDEMD_APPEND_EOF'

## AI Context Library

This project uses the **ai-context-library** pattern: `.library/` is the git-tracked source of truth, and `.claude/commands/` + `.claude/skills/` contain only symlinks managed by toggle scripts.

### Key Commands

- `/toggle-commands` — Enable/disable command groups
- `/toggle-skills` — Enable/disable skill groups
- `/organize-library` — Detect and organize files dropped into `.claude/`
- `/import-repo` — Import skills/commands from a GitHub repository

### Quick Reference

```bash
bash scripts/toggle-commands.sh list        # Show command group status
bash scripts/toggle-skills.sh list          # Show skill group status
bash scripts/organize-library.sh scan       # Find unorganized files
```

## Notes

- ExFAT drive: macOS creates `._*` resource fork files — the toggle scripts clean these automatically.
- Scripts assume they're run from the repo root.
CLAUDEMD_APPEND_EOF
        ok "Appended AI Context Library section to CLAUDE.md"
    else
        ok "CLAUDE.md already has AI Context Library section — skipped"
    fi
}

# ─── Phase 8: Summary ────────────────────────────────────────────────────────
phase8_summary() {
    echo ""
    printf "${GREEN}══════════════════════════════════════════════════════════${NC}\n"
    printf "${GREEN}  Setup complete!${NC}\n"
    printf "${GREEN}══════════════════════════════════════════════════════════${NC}\n"
    echo ""

    # Count installed files
    local speckit_cmds=$(find .library/commands/speckit -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    local project_cmds=$(find .library/commands/project -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    local templates=$(find .specify/templates -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    local bash_scripts=$(find .specify/scripts/bash -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')
    local toggle_scripts=$(find scripts -name "*.sh" 2>/dev/null | wc -l | tr -d ' ')

    echo "  Installed:"
    echo "    $speckit_cmds speckit commands       → .library/commands/speckit/"
    echo "    $project_cmds project commands       → .library/commands/project/"
    echo "    $templates templates               → .specify/templates/"
    echo "    $bash_scripts speckit bash scripts    → .specify/scripts/bash/"
    echo "    $toggle_scripts toggle/utility scripts → scripts/"
    echo ""
    echo "  Active symlinks:"
    bash scripts/toggle-commands.sh list 2>/dev/null | sed 's/^/    /'
    bash scripts/toggle-skills.sh list 2>/dev/null | sed 's/^/    /'
    echo ""
    echo "  Next steps:"
    echo "    1. Edit CLAUDE.md — update project name and description"
    echo "    2. Edit .specify/memory/constitution.md — define project rules"
    echo "    3. Run /toggle-commands list — verify command groups"
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    printf "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}\n"
    printf "${BLUE}║  init-custom-speckit.sh — One-Shot Setup                ║${NC}\n"
    printf "${BLUE}║  spec-kit + ai-context-library                         ║${NC}\n"
    printf "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}\n"
    echo ""

    phase0_install_speckit
    phase1_validate
    phase2_create_dirs
    phase3_clone
    phase4_copy_speckit
    phase5_copy_aicl
    phase6_generate_toggle_skills
    phase7_post_install
    phase8_summary
}

main "$@"

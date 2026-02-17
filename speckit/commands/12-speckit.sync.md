---
description: Sync features.yaml with current branch state and regenerate CLAUDE.md Feature History table.
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Purpose

This skill synchronizes the `speckit-helpers/features.yaml` file with the current feature branch state and regenerates the auto-generated Feature History section in `CLAUDE.md`.

## Arguments

- `--feature NNN` or `-f NNN`: Update a specific feature by ID (e.g., `--feature 008`)
- `--status STATUS` or `-s STATUS`: Set the feature status (ideating|specified|planned|implementing|completed)
- `--pr-number N`: Set the PR number after merge
- `--pr-summary PATH`: Set the path to PR summary file
- No arguments: Full sync - detect current branch, update key_files from diff, regenerate CLAUDE.md

## Execution Flow

### Step 1: Determine Current Feature

1. If `--feature` is provided, use that feature ID
2. Otherwise, detect from current branch name:
   ```bash
   git branch --show-current
   ```
   - Extract feature ID from branch name pattern `NNN-feature-name` (e.g., `008-token-usage-tracking` → `008`)
   - If on `main` or branch doesn't match pattern, prompt user for feature ID

### Step 2: Read Current State

1. Read `speckit-helpers/features.yaml`
2. Find the feature entry by ID
3. If feature doesn't exist and we have a branch name, create a new entry with defaults

### Step 3: Auto-Detect Key Files from Git Diff

Run git diff to find changed files compared to main branch:

```bash
# Get list of changed files (added, modified, renamed)
git diff --name-only main...HEAD --diff-filter=ACMR
```

**Filter key files**:
- Include: `src/**/*.ts`, `src/**/*.tsx`, `prisma/**/*.prisma`, `prisma/**/*.ts`
- Exclude: `*.test.ts`, `*.spec.ts`, `tests/**`, `__tests__/**`, `*.d.ts`
- Prioritize by importance:
  1. Schema files (`prisma/schema.prisma`)
  2. Route files (`src/app/**/route.ts`, `src/app/**/page.tsx`)
  3. Service files (`src/server/services/**`)
  4. Component files (`src/components/**`)
  5. Utility files (`src/lib/**`)

**Limit to top 15 most important files** to keep the list manageable.

### Step 4: Verify Diff Against PR Summary (if exists)

If a PR summary exists for this feature (`pull_request_summary/NNN-*.md`):

1. Read the PR summary
2. Extract file paths mentioned in "Key Files", "Modified Files", or similar sections
3. Compare with git diff results
4. Report any discrepancies:
   - Files in diff but not in PR summary (new changes since PR?)
   - Files in PR summary but not in diff (removed changes?)
5. Do NOT auto-fix - just report for user awareness

### Step 5: Update features.yaml

Update the feature entry with:

```yaml
- id: "NNN"
  name: "Feature Name"  # From branch name or existing
  status: STATUS  # From --status or existing
  description: "..."  # From existing or spec.md if available

  artifacts:
    spec: "specs/NNN-name/spec.md"  # If exists
    plan: "specs/NNN-name/plan.md"  # If exists
    tasks: "specs/NNN-name/tasks.md"  # If exists
    pr_summary: "pull_request_summary/NNN-*.md"  # If exists
    pr_number: N  # From --pr-number or existing

  key_files:
    - path/to/file1.ts  # From git diff (top 15)
    - path/to/file2.ts

  patterns_used: []  # Keep existing, don't auto-detect
  decisions: []  # Keep existing, don't auto-detect

  depends_on: []  # Keep existing
  enables: []  # Keep existing
```

**Auto-detect artifacts**:
```bash
# Check if spec exists
ls specs/NNN-*/spec.md 2>/dev/null

# Check if plan exists
ls specs/NNN-*/plan.md 2>/dev/null

# Check if tasks exists
ls specs/NNN-*/tasks.md 2>/dev/null

# Check if PR summary exists
ls pull_request_summary/NNN-*.md 2>/dev/null
```

### Step 6: Regenerate CLAUDE.md Feature History

1. Read `speckit-helpers/features.yaml`
2. Generate the Feature History table:

```markdown
## Feature History

<!-- AUTO-GENERATED FROM speckit-helpers/features.yaml - Run /speckit.sync to update -->

| # | Feature | Status | Description | Key Files |
|---|---------|--------|-------------|-----------|
| 001 | Feature Name | ✅ | Short description | `file1.ts`, `file2.ts` |
| 002 | Feature Name | 🚧 | Short description | TBD |

**Full details**: `speckit-helpers/features.yaml`

<!-- END AUTO-GENERATED -->
```

**Status icons**:
- `completed` → ✅
- `implementing` → 🔧
- `planned` → 📋
- `specified` → 📝
- `ideating` → 💡

**Key Files display**:
- Show first 2-3 key files abbreviated (just filename, no path)
- If no key_files, show "TBD"

3. Find and replace the section in CLAUDE.md between:
   - Start: `## Feature History`
   - End: `<!-- END AUTO-GENERATED -->`

### Step 7: Validate and Report

1. Validate YAML syntax of features.yaml
2. Report summary:

```markdown
## Sync Complete

**Feature**: 008 - Token Usage Tracking
**Status**: planned

### Key Files Updated (from git diff)
- prisma/schema.prisma
- src/server/services/token-service.ts
- src/app/api/admin/tokens/route.ts
- ... (N total)

### Artifacts Detected
- [x] spec.md
- [x] plan.md
- [ ] tasks.md
- [ ] pr_summary

### PR Summary Verification
✅ No discrepancies found
(or)
⚠️ Discrepancies found:
- `src/new-file.ts` in diff but not in PR summary
- `src/old-file.ts` in PR summary but not in diff

### CLAUDE.md Updated
Feature History table regenerated with 8 features.
```

## Error Handling

- **features.yaml doesn't exist**: Create it with template structure
- **Feature ID not found and no branch**: Prompt user to specify `--feature`
- **Invalid YAML after update**: Rollback and report error
- **CLAUDE.md missing Feature History section**: Add it before `## Brand Style Guide` or at end

## Examples

```bash
# Sync current branch (auto-detect feature from branch name)
/12-speckit.sync

# Sync specific feature
/12-speckit.sync --feature 008

# Update status after implementation complete
/12-speckit.sync --feature 008 --status completed

# Full update after PR merge
/12-speckit.sync --feature 007 --status completed --pr-number 10 --pr-summary pull_request_summary/007-admin-dashboard.md
```

## Notes

- This skill is designed to be run manually, not auto-triggered by other skills
- Key files are auto-detected from git diff to ensure accuracy
- PR summary verification is informational only - it reports but doesn't auto-fix
- The skill preserves manually-added `patterns_used`, `decisions`, and dependency fields
- Only `key_files`, `status`, and `artifacts` are auto-updated

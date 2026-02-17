---
description: Pre-implementation blocker scan for tasks.md. Identifies tasks requiring human intervention (credentials, API keys, OAuth setup, database access, CLI installations) before autonomous implementation. Run this BEFORE /11-speckit.implement to ensure all prerequisites are in place for fully autonomous execution. Use when preparing for implementation or when user asks about blockers, prerequisites, or "what do I need to do before implementing".
---

# Pre-Flight Blocker Scan

Scan tasks.md to identify human-required actions before autonomous implementation.

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Execution

### 1. Setup

Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks` from repo root. Parse FEATURE_DIR.

For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

### 2. Load & Parse tasks.md

Read `FEATURE_DIR/tasks.md`. Extract all task lines matching:
```
- [ ] T### ...description...
```

### 3. Detect Blockers

Scan each task description for blocker keywords. Categorize matches:

#### Category: Credentials & Secrets
**Keywords**: `.env`, `API_KEY`, `SECRET`, `TOKEN`, `PASSWORD`, `CREDENTIALS`, `apiKey`, `secret`, `password`, `OPENAI_API_KEY`, `DATABASE_URL`, `NEXTAUTH_SECRET`, `CLIENT_ID`, `CLIENT_SECRET`

**Blocker if task mentions**: setting up, configuring, adding, or creating any of these

#### Category: External Access & Permissions
**Keywords**: `OAuth`, `authentication`, `authorize`, `permission`, `access grant`, `service account`, `IAM`, `RBAC`, `Figma Developer Console`, `callback URL`, `redirect URI`, `S3 bucket`, `database access`, `connection string`

**Blocker if task mentions**: setting up OAuth apps, granting permissions, creating service accounts

#### Category: Manual Installations
**Keywords**: `install`, `brew`, `apt`, `npm install -g`, `pip install`, `cargo install`, `setup CLI`, `download`, `binary`, `Prisma Studio` (if requires local setup), `Docker`, `PostgreSQL`, `Redis`

**Blocker if task mentions**: installing tools or services that require human action

#### Category: External Service Setup
**Keywords**: `create bucket`, `create database`, `provision`, `deploy to`, `set up server`, `configure CDN`, `DNS`, `SSL certificate`, `Vercel`, `AWS`, `GCP`, `Azure`

**Blocker if task mentions**: creating or provisioning external resources

### 4. Build Blocker List

For each detected blocker, extract:
- **Task ID**: T001, T002, etc.
- **Category**: One of the four categories above
- **Description**: The task description
- **Action Required**: What the human needs to do
- **Verification**: How to confirm it's done

### 5. Interactive Walkthrough

If blockers found, present them one-by-one:

```markdown
## Pre-Flight Check: [X] Blockers Found

### Blocker 1 of N: [Category]

**Task**: T### - [description]

**Action Required**:
[Specific instructions for what the human needs to do]

**Verification**:
[Command or check to verify completion]

---
Ready to verify? (yes/skip/abort)
```

Use AskUserQuestion for each blocker:
- **yes**: Run verification, mark as resolved if passes
- **skip**: Move to next blocker (will be flagged at end)
- **abort**: Stop preflight, show summary of remaining blockers

### 6. Verification Commands

Common verifications:

| Blocker Type | Verification |
|--------------|--------------|
| .env variable | `grep VAR_NAME .env.local` or check file exists |
| Database URL | `npx prisma db pull --print` (connects successfully) |
| OAuth setup | Check callback URL configured in provider console |
| CLI tool | `which <tool>` or `<tool> --version` |
| npm package | `npm list <package>` |
| Docker | `docker info` |

### 7. Final Report

After all blockers processed:

```markdown
## Pre-Flight Complete

| Status | Count |
|--------|-------|
| Resolved | X |
| Skipped | Y |
| Total | Z |

### Resolved Blockers
- T001: [description] ✓

### Skipped Blockers (Manual Action Required)
- T005: [description] - [what's needed]

### Recommendation
[If all resolved]: Ready for `/11-speckit.implement` - autonomous execution enabled
[If skipped exist]: Complete skipped items before running `/11-speckit.implement`
```

## Blocker Detection Patterns

### Pattern: Environment Variables

```regex
\.(env|ENV)|API[_-]?KEY|SECRET|TOKEN|PASSWORD|CREDENTIALS|DATABASE_URL
```

**Action template**:
```
Add [VAR_NAME] to .env.local:
1. Copy from .env.local.example if exists
2. Or create: echo "VAR_NAME=your-value" >> .env.local
3. Get value from: [source - e.g., "Anthropic Console > API Keys"]
```

### Pattern: OAuth Setup

```regex
OAuth|Figma.*(Client|Developer)|callback.*URL|redirect.*URI|NEXTAUTH
```

**Action template**:
```
Configure OAuth in [Provider] Developer Console:
1. Go to [URL]
2. Create app or select existing
3. Add callback URL: http://localhost:3000/api/auth/callback/[provider]
4. Copy Client ID and Secret to .env.local
```

### Pattern: Database

```regex
DATABASE_URL|Prisma.*migrate|PostgreSQL|create.*database|db.*setup
```

**Action template**:
```
Set up database:
1. Ensure PostgreSQL is running locally or use hosted service
2. Create database: createdb [dbname]
3. Set DATABASE_URL in .env.local
4. Run: npx prisma migrate dev
```

### Pattern: CLI Tools

```regex
npx prisma studio|brew install|apt install|npm install -g|pip install
```

**Action template**:
```
Install required tool:
1. Run: [install command]
2. Verify: [version command]
```

## Non-Blockers (Claude Can Handle)

These are NOT blockers - Claude can execute them autonomously:
- Creating directories
- Writing code files
- Running `npm install` (dependencies, not global tools)
- Running `npx prisma generate`
- Running `npx prisma migrate dev` (if DATABASE_URL is set)
- Creating TypeScript interfaces
- Updating existing files
- Running tests
- Git operations

## Edge Cases

- **Task mentions .env but is about reading**: Not a blocker if Claude can read existing .env
- **Task mentions "verify" or "check"**: Usually not a blocker, just validation
- **Task mentions "if not exists"**: May not be a blocker if optional
- **Multiple blockers in one task**: List each separately with same Task ID

## Project-Specific Reference (design-2-liquid)

### Required Environment Variables (.env.local)

| Variable | Source | Purpose |
|----------|--------|---------|
| `DATABASE_URL` | PostgreSQL connection string | Prisma database connection |
| `OPENAI_API_KEY` | [OpenAI Console](https://platform.openai.com/api-keys) | LangChain LLM calls |
| `FIGMA_CLIENT_ID` | [Figma Developer Console](https://www.figma.com/developers/apps) | OAuth authentication |
| `FIGMA_CLIENT_SECRET` | Figma Developer Console | OAuth authentication |
| `NEXTAUTH_SECRET` | Generate: `openssl rand -base64 32` | Session encryption |
| `NEXTAUTH_URL` | `http://localhost:3000` (dev) | Auth callback base URL |

### Quick Verification

```bash
# Check required env vars exist
grep -E "DATABASE_URL|OPENAI_API_KEY|FIGMA_CLIENT" .env.local

# Test database connection
npx prisma db pull --print

# Check PostgreSQL running
pg_isready -h localhost -p 5432
```

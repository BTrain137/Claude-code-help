# Claude Code Setup Guide

Quick reference for setting up Claude Code on a new machine.

## Prerequisites

- `jq` installed (`brew install jq` on macOS, `apt install jq` on Linux)
- `bc` installed (usually pre-installed on macOS/Linux)

## 1. Create `~/.claude/settings.json`

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-command.sh"
  }
}
```

## 2. Create `~/.claude/statusline-command.sh`

```bash
#!/bin/bash

# Read JSON from stdin
input=$(cat)

# Extract values
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
model_name=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
dir=$(echo "$input" | jq -r '.workspace.current_dir // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# --- Project-level delegation (safe: project scripts are self-contained) ---
# If the current project has its own .claude/statusline-command.sh, hand off
# to it entirely via exec. No output has been produced yet, so there is no
# risk of duplication. Team members without this global script simply get the
# default status line; they are never affected by the project script.
if [ -n "$dir" ] && [ -f "${dir}/.claude/statusline-command.sh" ]; then
  exec bash "${dir}/.claude/statusline-command.sh" <<< "$input"
fi

# Colors
CYAN='\033[96m'
YELLOW='\033[93m'
BRIGHT_GREEN='\033[92m'
BRIGHT_YELLOW='\033[93m'
BRIGHT_RED='\033[91m'
GOLD='\033[38;5;220m'
MAGENTA='\033[95m'
BLUE='\033[94m'
BRIGHT_BLUE='\033[38;5;39m'
BRIGHT_MAGENTA='\033[95m'
CORAL='\033[38;5;209m'
WHITE='\033[97m'
DIM_WHITE='\033[2;37m'
RESET='\033[0m'

# --- Daily usage tracking ---
USAGE_DIR="$HOME/.claude/usage"
mkdir -p "$USAGE_DIR"
TODAY=$(date +%Y-%m-%d)
DAILY_FILE="$USAGE_DIR/$TODAY.tsv"
SESSION_ID="$PPID"

# Update this session's line in the daily file (cost-based tracking)
session_tokens=$((total_input + total_output))
if [ -f "$DAILY_FILE" ]; then
  # Remove existing line for this session, then append updated one
  grep -v "^${SESSION_ID}	" "$DAILY_FILE" > "$DAILY_FILE.tmp" 2>/dev/null || true
  mv "$DAILY_FILE.tmp" "$DAILY_FILE"
fi
printf "%s\t%s\t%s\n" "$SESSION_ID" "$session_tokens" "$cost" >> "$DAILY_FILE"

# Sum all sessions for today
daily_tokens=0
daily_cost=0
while IFS=$'\t' read -r _sid tokens sess_cost; do
  daily_tokens=$((daily_tokens + ${tokens:-0}))
  daily_cost=$(echo "$daily_cost + ${sess_cost:-0}" | bc)
done < "$DAILY_FILE"

# --- JSONL-based token aggregation (accurate billing, cached 30s) ---
JSONL_CACHE="$USAGE_DIR/jsonl-daily-tokens.cache"
JSONL_CACHE_TIME="$USAGE_DIR/jsonl-daily-tokens.cache.time"
NOW_EPOCH=$(date +%s)
CACHE_VALID=0
if [ -f "$JSONL_CACHE_TIME" ] && [ -f "$JSONL_CACHE" ]; then
  CACHE_EPOCH=$(cat "$JSONL_CACHE_TIME" 2>/dev/null || echo 0)
  CACHE_AGE=$(( NOW_EPOCH - CACHE_EPOCH ))
  [ "$CACHE_AGE" -le 30 ] && CACHE_VALID=1
fi

if [ "$CACHE_VALID" -eq 1 ]; then
  jsonl_daily_tokens=$(cat "$JSONL_CACHE")
else
  jsonl_daily_tokens=0
  PROJECTS_DIR="$HOME/.claude/projects"
  if [ -d "$PROJECTS_DIR" ]; then
    # Sum input+output tokens from JSONL log entries created today
    while IFS= read -r -d '' jsonl_file; do
      file_tokens=$(
        grep -h '"type":"usage"' "$jsonl_file" 2>/dev/null \
        | grep "\"$(date +%Y-%m-%d)" 2>/dev/null \
        | jq -r '(.input_tokens // 0) + (.output_tokens // 0)' 2>/dev/null \
        | awk '{s+=$1} END{print s+0}'
      )
      jsonl_daily_tokens=$(( jsonl_daily_tokens + file_tokens ))
    done < <(find "$PROJECTS_DIR" -name "*.jsonl" -newer "$USAGE_DIR/$TODAY.tsv" -print0 2>/dev/null || true)
    # Fallback: scan all jsonl files if daily file doesn't exist yet
    if [ "$jsonl_daily_tokens" -eq 0 ]; then
      jsonl_daily_tokens=$(
        find "$PROJECTS_DIR" -name "*.jsonl" -print0 2>/dev/null \
        | xargs -0 grep -h '"type":"usage"' 2>/dev/null \
        | grep "\"$(date +%Y-%m-%d)" 2>/dev/null \
        | jq -r '(.input_tokens // 0) + (.output_tokens // 0)' 2>/dev/null \
        | awk '{s+=$1} END{print s+0}'
      )
    fi
  fi
  echo "$jsonl_daily_tokens" > "$JSONL_CACHE"
  echo "$NOW_EPOCH" > "$JSONL_CACHE_TIME"
fi

# Use JSONL tokens if available (more accurate), otherwise fall back to session-sum
if [ "${jsonl_daily_tokens:-0}" -gt 0 ]; then
  daily_tokens=$jsonl_daily_tokens
fi

# Clean up old daily files (keep 7 days)
find "$USAGE_DIR" -name "*.tsv" -mtime +7 -delete 2>/dev/null

# Format tokens as X.Xk or XXXk
format_tokens() {
  local tokens=$1
  if [ "$tokens" -ge 1000000 ]; then
    local m=$(echo "scale=1; $tokens / 1000000" | bc)
    m=$(echo "$m" | sed 's/\.0$//')
    echo "${m}M"
  elif [ "$tokens" -ge 1000 ]; then
    local k=$(echo "scale=1; $tokens / 1000" | bc)
    k=$(echo "$k" | sed 's/\.0$//')
    echo "${k}k"
  else
    echo "$tokens"
  fi
}

# Line 1: directory + git branch (always show)
folder="${dir##*/}"
branch=""
if git rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null)
fi

if [ -n "$branch" ]; then
  printf "📁 ${BLUE}${folder}${RESET} ${WHITE}|${RESET} 🌿 ${BRIGHT_MAGENTA}${branch}${RESET}\n"
else
  printf "📁 ${BLUE}${folder}${RESET}\n"
fi

# If no context data yet, show initial state and exit
if [ -z "$used_pct" ] || [ "$used_pct" = "null" ]; then
  daily_cost_fmt=$(printf '%.2f' "$daily_cost")
  formatted_daily=$(format_tokens $daily_tokens)
  printf "${WHITE}[${BRIGHT_GREEN}0%% 0/200k${WHITE}]${RESET} ${GOLD}|${RESET} ${GOLD}\$%s${RESET} ${WHITE}|${RESET} ${WHITE}%s tokens${RESET} ${CORAL}|${RESET} ${CORAL}%s${RESET}\n" "$daily_cost_fmt" "$formatted_daily" "$model_name"
  EMPTY_BAR=$(printf "%30s" | tr ' ' '░')
  printf "${DIM_WHITE}${EMPTY_BAR}${RESET}\n"
  exit 0
fi

total_tokens=$((total_input + total_output))
formatted_total=$(format_tokens $total_tokens)
formatted_context=$(format_tokens $context_size)

# Calculate actual context usage from percentage
context_used=$(echo "$used_pct * $context_size / 100" | bc | cut -d. -f1)
formatted_context_used=$(format_tokens $context_used)

# Format cost
cost_fmt=$(printf '%.2f' "$cost")
daily_cost_fmt=$(printf '%.2f' "$daily_cost")
formatted_daily=$(format_tokens $daily_tokens)

# Pick context color based on usage: 0-33% green, 34-66% yellow, 67%+ red
pct_int=$(printf '%.0f' "$used_pct")
if [ "$pct_int" -le 33 ]; then
  CTX_COLOR="$BRIGHT_GREEN"
elif [ "$pct_int" -le 66 ]; then
  CTX_COLOR="$BRIGHT_YELLOW"
else
  CTX_COLOR="$BRIGHT_RED"
fi

# Line 2: [46% 93.3k/200k] | $32.10 | 850k tokens | Opus 4.6
printf "${WHITE}[${CTX_COLOR}%.0f%% %s${WHITE}/${RESET}${BRIGHT_BLUE}%s${WHITE}]${RESET} ${GOLD}|${RESET} ${GOLD}\$%s${RESET} ${WHITE}|${RESET} ${WHITE}%s tokens${RESET} ${CORAL}|${RESET} ${CORAL}%s${RESET}\n" \
  "$used_pct" \
  "$formatted_context_used" \
  "$formatted_context" \
  "$daily_cost_fmt" \
  "$formatted_daily" \
  "$model_name"

# Line 3: progress bar
BAR_WIDTH=30
FILLED=$((pct_int * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && BAR=$(printf "%${FILLED}s" | tr ' ' '█')
EMPTY_BAR=""
[ "$EMPTY" -gt 0 ] && EMPTY_BAR=$(printf "%${EMPTY}s" | tr ' ' '░')
printf "${CTX_COLOR}${BAR}${DIM_WHITE}${EMPTY_BAR}${RESET}\n"
```

## 3. Make it executable

```bash
chmod +x ~/.claude/statusline-command.sh
```

## What it looks like

### On initial load (no messages yet)
```
📁 my-project | 🌿 feat/my-branch
[0% 0/200k] | $0.00 | 0 tokens | Opus 4.6
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

### During a session (mid-day, multiple sessions)
```
📁 my-project | 🌿 feat/my-branch
[24% 48.2k/200k] | $32.10 | 850k tokens | Opus 4.6
███████░░░░░░░░░░░░░░░░░░░░░░░
```

### High usage (67%+)
```
📁 my-project | 🌿 feat/my-branch
[78% 156k/200k] | $45.30 | 1.2M tokens | Opus 4.6
███████████████████████░░░░░░░░
```

## Line 2 Breakdown

```
[76% 152k/200k] | $32.10 | 850k tokens | Opus 4.6
 ^^^  ^^^  ^^^    ^^^^^^   ^^^^^^^^^^    ^^^^^^^^
  |    |    |       |          |            |
  |    |    |       |          |            └─ Model name
  |    |    |       |          └─ Daily total tokens (all sessions today)
  |    |    |       └─ Daily total cost (all sessions today)
  |    |    └─ Context window size
  |    └─ Current context usage (derived from % * window size)
  └─ Context usage percentage
```

## Color Map

| Element               | Color                      | Code                                          |
|-----------------------|----------------------------|-----------------------------------------------|
| Brackets `[ ]`        | White                      | `\033[97m`                                    |
| % + used tokens       | Green/Yellow/Red (dynamic) | `\033[92m` / `\033[93m` / `\033[91m`          |
| `/`                   | White                      | `\033[97m`                                    |
| Context window size   | Bright Blue                | `\033[38;5;39m`                               |
| Pipes `\|`            | Next section's color       | --                                            |
| Daily cost `$X.XX`    | Gold                       | `\033[38;5;220m`                              |
| Daily total tokens    | White                      | `\033[97m`                                    |
| Model name            | Coral/Salmon               | `\033[38;5;209m`                              |
| Directory             | Blue                       | `\033[94m`                                    |
| Branch                | Bright Magenta             | `\033[95m`                                    |
| Progress bar (filled) | Green/Yellow/Red (dynamic) | Same as context color                         |
| Progress bar (empty)  | Dim White                  | `\033[2;37m`                                  |

## Context Color Thresholds

| Usage   | Color          | Applies to                    |
|---------|----------------|-------------------------------|
| 0-33%   | Bright Green   | % + used tokens, progress bar |
| 34-66%  | Bright Yellow  | % + used tokens, progress bar |
| 67-100% | Bright Red     | % + used tokens, progress bar |

## Daily Usage Tracking

Cost and token totals are tracked across all Claude Code sessions per day.

### Cost tracking (from session data)
- **Storage**: `~/.claude/usage/YYYY-MM-DD.tsv` (one file per day)
- **Format**: Each line is `SESSION_ID<tab>TOKENS<tab>COST`
- **Source**: `cost.total_cost_usd` from Claude Code's live session data (authoritative)
- **Updates**: Each statusline refresh updates the current session's cost, then sums all sessions

### Token tracking (from JSONL files)
- **Source**: Per-API-call `message.usage` blocks in `~/.claude/projects/*.jsonl`
- **Token types counted**: `input_tokens` + `output_tokens`
- **Cache**: Results cached at `~/.claude/usage/jsonl-daily-tokens.cache`, refreshes every 30 seconds
- **Scope**: Only scans JSONL files modified since the daily TSV file for performance
- **Fallback**: If no recent files found, scans all JSONL files for today's date

### Why JSONL-based token tracking?

The previous approach summed `context_window.total_input_tokens + total_output_tokens` from session data. These are **cumulative context window totals** that re-count the full conversation history on every turn — inflating the number well beyond actual API consumption.

The current approach reads per-API-call tokens from Claude Code's JSONL log files (`~/.claude/projects/`). Each JSONL entry records the actual tokens consumed by a single API call, which is what Anthropic bills for. This gives an accurate picture of real token usage.

### General
- **Session ID**: Parent process ID (`$PPID`), unique per Claude Code instance
- **Cleanup**: TSV files older than 7 days are automatically deleted
- **Token formatting**: Uses `k` suffix for thousands, `M` suffix for millions (e.g. `850k`, `1.2M`)

## Features

- Shows directory + git branch on initial load (before any messages)
- Displays zeroed-out stats with empty progress bar on first load
- Dynamic color coding for context usage (green/yellow/red)
- Context bracket shows actual window usage (not cumulative session tokens)
- Daily cost totals across all sessions (from Claude's session data)
- Daily token totals from JSONL per-API-call data (actual billed tokens, cached 30s)
- Human-readable token formatting (e.g. `93.3k`, `1.2M`)
- 30-character progress bar with filled/empty block characters
- Auto-cleanup of usage files older than 7 days
- Per-project banner overrides via project-level `.claude/statusline-command.sh`

## 4. Per-Project Statusline Override (Optional)

You can add a colored project banner above the standard statusline on a per-project basis. This makes it easy to identify which project you're working in at a glance.

### How it works

The global `~/.claude/statusline-command.sh` (from step 2) includes a **project delegation block** near the top:

```bash
if [ -n "$dir" ] && [ -f "${dir}/.claude/statusline-command.sh" ]; then
  exec bash "${dir}/.claude/statusline-command.sh" <<< "$input"
fi
```

This checks if the current project has its own `.claude/statusline-command.sh`. If found, it `exec`s into it — replacing the global script entirely. The project script is **self-contained** and renders everything (banner + all standard info) without calling back to the global script.

**Key design decisions:**
- Uses `exec` (not a subshell) so only one script ever produces output — no duplication possible
- The project script is fully self-contained — no circular calls back to the global script
- No changes needed to project-level `.claude/settings.json` — safe for shared repos where teammates may have different directory structures
- Team members without the global delegation script are unaffected; the project files just sit there unused

**Call chain:**
```
Claude Code
  → ~/.claude/statusline-command.sh   (global, reads JSON)
      → checks for {cwd}/.claude/statusline-command.sh
          [found]  exec → project script runs, global is gone
          [not found]  global script continues and renders normally
```

### Step 1: Create `<project>/.claude/statusline.conf`

This is the only file you need to edit per project. It controls the banner title and color:

```bash
# statusline.conf — per-project banner configuration
# Sourced by .claude/statusline-command.sh at render time.
# Changes take effect immediately; no restart needed.
#
# BANNER_TITLE : text displayed in the centre of the banner strip
# BANNER_COLOR : a number from 0-255 selecting a 256-color palette entry
#
# Quick color reference (256-color palette):
#   Red        196   Bright red    203   Orange       208   Yellow       226
#   Green       46   Bright green   82   Lime         118   Teal          37
#   Blue        27   Bright blue    39   Sky           75   Cyan          51
#   Purple     135   Violet        141   Magenta      201   Pink         213
#   Brown      130   Gold          220   White        255   Grey         240
#
# Full chart: https://www.ditig.com/256-colors-cheat-sheet

BANNER_TITLE="My Project"
BANNER_COLOR=135   # purple
```

### Step 2: Create `<project>/.claude/statusline-command.sh`

This script is self-contained. It renders the project banner, then all the standard info (folder, branch, context, cost, tokens, progress bar). It does **not** call back to the global script.

```bash
#!/bin/bash

# Project-specific statusline for this repo.
# Self-contained: renders the project banner then all standard info.
# Does NOT call the global statusline script to avoid circular delegation.
#
# CUSTOMIZATION
# Edit .claude/statusline.conf (in the same directory as this script) to change
# the banner title and color without touching this file.  Available keys:
#
#   BANNER_TITLE="My Project"   # text shown in the centre of the banner
#   BANNER_COLOR=135            # 256-color palette number (0-255) for fg + bg

# Read JSON from stdin
input=$(cat)

# --- Banner config (defaults, overridden by statusline.conf if present) ---
BANNER_TITLE="My Project"   # default (overridden by statusline.conf)
BANNER_COLOR=135             # default (overridden by statusline.conf)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="${SCRIPT_DIR}/statusline.conf"
# shellcheck source=/dev/null
[ -f "$CONF_FILE" ] && source "$CONF_FILE"

# Extract values
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
context_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
model_name=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
dir=$(echo "$input" | jq -r '.workspace.current_dir // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

# Colors
BRIGHT_GREEN='\033[92m'
BRIGHT_YELLOW='\033[93m'
BRIGHT_RED='\033[91m'
GOLD='\033[38;5;220m'
BLUE='\033[94m'
BRIGHT_BLUE='\033[38;5;39m'
BRIGHT_MAGENTA='\033[95m'
CORAL='\033[38;5;209m'
WHITE='\033[97m'
DIM_WHITE='\033[2;37m'
BOLD='\033[1m'
RESET='\033[0m'

# Build banner escape codes from the configured color number
BANNER_FG="\033[38;5;${BANNER_COLOR}m"
BANNER_BG="\033[48;5;${BANNER_COLOR}m"

# --- Project banner ---
PAD_LEN=20
LEFT_PAD=$(printf "%${PAD_LEN}s" | tr ' ' '█')
RIGHT_PAD=$(printf "%${PAD_LEN}s" | tr ' ' '█')
printf "${BANNER_FG}${LEFT_PAD}${BANNER_BG}${WHITE}${BOLD} ${BANNER_TITLE} ${RESET}${BANNER_FG}${RIGHT_PAD}${RESET}\n"

# --- Daily usage tracking ---
USAGE_DIR="$HOME/.claude/usage"
mkdir -p "$USAGE_DIR"
TODAY=$(date +%Y-%m-%d)
DAILY_FILE="$USAGE_DIR/$TODAY.tsv"
SESSION_ID="$PPID"

session_tokens=$((total_input + total_output))
if [ -f "$DAILY_FILE" ]; then
  grep -v "^${SESSION_ID}	" "$DAILY_FILE" > "$DAILY_FILE.tmp" 2>/dev/null || true
  mv "$DAILY_FILE.tmp" "$DAILY_FILE"
fi
printf "%s\t%s\t%s\n" "$SESSION_ID" "$session_tokens" "$cost" >> "$DAILY_FILE"

daily_tokens=0
daily_cost=0
while IFS=$'\t' read -r _sid tokens sess_cost; do
  daily_tokens=$((daily_tokens + ${tokens:-0}))
  daily_cost=$(echo "$daily_cost + ${sess_cost:-0}" | bc)
done < "$DAILY_FILE"

# --- JSONL-based token aggregation (accurate billing, cached 30s) ---
JSONL_CACHE="$USAGE_DIR/jsonl-daily-tokens.cache"
JSONL_CACHE_TIME="$USAGE_DIR/jsonl-daily-tokens.cache.time"
NOW_EPOCH=$(date +%s)
CACHE_VALID=0
if [ -f "$JSONL_CACHE_TIME" ] && [ -f "$JSONL_CACHE" ]; then
  CACHE_EPOCH=$(cat "$JSONL_CACHE_TIME" 2>/dev/null || echo 0)
  CACHE_AGE=$(( NOW_EPOCH - CACHE_EPOCH ))
  [ "$CACHE_AGE" -le 30 ] && CACHE_VALID=1
fi

if [ "$CACHE_VALID" -eq 1 ]; then
  jsonl_daily_tokens=$(cat "$JSONL_CACHE")
else
  jsonl_daily_tokens=0
  PROJECTS_DIR="$HOME/.claude/projects"
  if [ -d "$PROJECTS_DIR" ]; then
    while IFS= read -r -d '' jsonl_file; do
      file_tokens=$(
        grep -h '"type":"usage"' "$jsonl_file" 2>/dev/null \
        | grep "\"$(date +%Y-%m-%d)" 2>/dev/null \
        | jq -r '(.input_tokens // 0) + (.output_tokens // 0)' 2>/dev/null \
        | awk '{s+=$1} END{print s+0}'
      )
      jsonl_daily_tokens=$(( jsonl_daily_tokens + file_tokens ))
    done < <(find "$PROJECTS_DIR" -name "*.jsonl" -newer "$USAGE_DIR/$TODAY.tsv" -print0 2>/dev/null || true)
    if [ "$jsonl_daily_tokens" -eq 0 ]; then
      jsonl_daily_tokens=$(
        find "$PROJECTS_DIR" -name "*.jsonl" -print0 2>/dev/null \
        | xargs -0 grep -h '"type":"usage"' 2>/dev/null \
        | grep "\"$(date +%Y-%m-%d)" 2>/dev/null \
        | jq -r '(.input_tokens // 0) + (.output_tokens // 0)' 2>/dev/null \
        | awk '{s+=$1} END{print s+0}'
      )
    fi
  fi
  echo "$jsonl_daily_tokens" > "$JSONL_CACHE"
  echo "$NOW_EPOCH" > "$JSONL_CACHE_TIME"
fi

if [ "${jsonl_daily_tokens:-0}" -gt 0 ]; then
  daily_tokens=$jsonl_daily_tokens
fi

find "$USAGE_DIR" -name "*.tsv" -mtime +7 -delete 2>/dev/null

# Format tokens as X.Xk, XXXk, or X.XM
format_tokens() {
  local tokens=$1
  if [ "$tokens" -ge 1000000 ]; then
    local m=$(echo "scale=1; $tokens / 1000000" | bc)
    m=$(echo "$m" | sed 's/\.0$//')
    echo "${m}M"
  elif [ "$tokens" -ge 1000 ]; then
    local k=$(echo "scale=1; $tokens / 1000" | bc)
    k=$(echo "$k" | sed 's/\.0$//')
    echo "${k}k"
  else
    echo "$tokens"
  fi
}

# --- Line 1: directory + git branch ---
folder="${dir##*/}"
branch=""
if git -C "${dir:-.}" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "${dir:-.}" branch --show-current 2>/dev/null)
fi

if [ -n "$branch" ]; then
  printf "📁 ${BLUE}${folder}${RESET} ${WHITE}|${RESET} 🌿 ${BRIGHT_MAGENTA}${branch}${RESET}\n"
else
  printf "📁 ${BLUE}${folder}${RESET}\n"
fi

# --- Line 2 & 3: context / cost / tokens / model + progress bar ---
if [ -z "$used_pct" ] || [ "$used_pct" = "null" ]; then
  daily_cost_fmt=$(printf '%.2f' "$daily_cost")
  formatted_daily=$(format_tokens $daily_tokens)
  printf "${WHITE}[${BRIGHT_GREEN}0%% 0/200k${WHITE}]${RESET} ${GOLD}|${RESET} ${GOLD}\$%s${RESET} ${WHITE}|${RESET} ${WHITE}%s tokens${RESET} ${CORAL}|${RESET} ${CORAL}%s${RESET}\n" "$daily_cost_fmt" "$formatted_daily" "$model_name"
  EMPTY_BAR=$(printf "%30s" | tr ' ' '░')
  printf "${DIM_WHITE}${EMPTY_BAR}${RESET}\n"
  exit 0
fi

formatted_context=$(format_tokens $context_size)
context_used=$(echo "$used_pct * $context_size / 100" | bc | cut -d. -f1)
formatted_context_used=$(format_tokens $context_used)
daily_cost_fmt=$(printf '%.2f' "$daily_cost")
formatted_daily=$(format_tokens $daily_tokens)

pct_int=$(printf '%.0f' "$used_pct")
if [ "$pct_int" -le 33 ]; then
  CTX_COLOR="$BRIGHT_GREEN"
elif [ "$pct_int" -le 66 ]; then
  CTX_COLOR="$BRIGHT_YELLOW"
else
  CTX_COLOR="$BRIGHT_RED"
fi

printf "${WHITE}[${CTX_COLOR}%.0f%% %s${WHITE}/${RESET}${BRIGHT_BLUE}%s${WHITE}]${RESET} ${GOLD}|${RESET} ${GOLD}\$%s${RESET} ${WHITE}|${RESET} ${WHITE}%s tokens${RESET} ${CORAL}|${RESET} ${CORAL}%s${RESET}\n" \
  "$used_pct" \
  "$formatted_context_used" \
  "$formatted_context" \
  "$daily_cost_fmt" \
  "$formatted_daily" \
  "$model_name"

BAR_WIDTH=30
FILLED=$((pct_int * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && BAR=$(printf "%${FILLED}s" | tr ' ' '█')
EMPTY_BAR=""
[ "$EMPTY" -gt 0 ] && EMPTY_BAR=$(printf "%${EMPTY}s" | tr ' ' '░')
printf "${CTX_COLOR}${BAR}${DIM_WHITE}${EMPTY_BAR}${RESET}\n"
```

### Step 3: Make it executable

```bash
chmod +x <project>/.claude/statusline-command.sh
```

### What it looks like

With a project override:
```
████████████████████ My Project ████████████████████
📁 my-project | 🌿 feat/my-branch
[24% 48.2k/200k] | $32.10 | 850k tokens | Opus 4.6
███████░░░░░░░░░░░░░░░░░░░░░░░
```

Without a project override (global only):
```
📁 my-project | 🌿 feat/my-branch
[24% 48.2k/200k] | $32.10 | 850k tokens | Opus 4.6
███████░░░░░░░░░░░░░░░░░░░░░░░
```

### Customizing the color

Edit `.claude/statusline.conf` — only two values to change:

```bash
BANNER_TITLE="My Project"
BANNER_COLOR=135   # change this number
```

Quick color reference:

| Color          | Number | Color          | Number |
|----------------|--------|----------------|--------|
| Purple         | 135    | Blue           | 27     |
| Teal           | 37     | Green          | 46     |
| Orange         | 208    | Red            | 196    |
| Gold           | 220    | Pink           | 213    |
| Cyan           | 51     | Magenta        | 201    |

Full 256-color chart: https://www.ditig.com/256-colors-cheat-sheet

### Adding to a new project

1. Copy both files into `<project>/.claude/`:
   - `statusline-command.sh` (the self-contained script)
   - `statusline.conf` (title + color config)
2. `chmod +x <project>/.claude/statusline-command.sh`
3. Edit `statusline.conf` to set a unique title and color
4. No changes to `.claude/settings.json` needed — the global script auto-detects it

### Important notes

- The project `.claude/statusline-command.sh` is **self-contained** — it renders the banner AND all standard info. It does NOT call back to the global script.
- The global script delegates via `exec`, which replaces itself entirely. Only one script ever produces output, so duplication is impossible.
- No machine-specific paths in the project repo. Safe to commit and share with teammates.
- Teammates without the global delegation script are unaffected — the project files are inert for them.

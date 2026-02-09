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

# Update this session's line in the daily file
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
  daily_tokens=$((daily_tokens + tokens))
  daily_cost=$(echo "$daily_cost + $sess_cost" | bc)
done < "$DAILY_FILE"

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

Token and cost totals are tracked across all Claude Code sessions per day.

- **Storage**: `~/.claude/usage/YYYY-MM-DD.tsv` (one file per day)
- **Format**: Each line is `SESSION_ID<tab>TOKENS<tab>COST`
- **Session ID**: Parent process ID (`$PPID`), unique per Claude Code instance
- **Updates**: Each statusline refresh updates the current session's line, then sums all sessions
- **Cleanup**: Daily files older than 7 days are automatically deleted
- **Token formatting**: Uses `k` suffix for thousands, `M` suffix for millions (e.g. `850k`, `1.2M`)

## Features

- Shows directory + git branch on initial load (before any messages)
- Displays zeroed-out stats with empty progress bar on first load
- Dynamic color coding for context usage (green/yellow/red)
- Context bracket shows actual window usage (not cumulative session tokens)
- Daily token and cost totals across all sessions
- Human-readable token formatting (e.g. `93.3k`, `1.2M`)
- 30-character progress bar with filled/empty block characters
- Auto-cleanup of usage files older than 7 days
- Per-project banner overrides via project-level `.claude/statusline-command.sh`

## 4. Per-Project Statusline Override (Optional)

You can add a colored project banner above the global statusline on a per-project basis. This makes it easy to identify which project you're working in at a glance.

### How it works

1. The global `~/.claude/settings.json` points to `~/.claude/statusline-command.sh` (the default)
2. A project can override this by creating its own `.claude/statusline-command.sh` in the project root
3. The project script prints a custom banner, then pipes stdin through to the global script

Claude Code automatically uses `.claude/statusline-command.sh` in the project root if it exists, falling back to the global one.

### Create `<project>/.claude/statusline-command.sh`

```bash
#!/bin/bash

# Project-specific statusline: adds a colored project banner
# then runs the global statusline for all the standard info

# Capture stdin first (JSON session data)
input=$(cat)

# Project banner colors - customize these per project
COLOR='\033[38;5;135m'        # Text/border color (purple)
COLOR_BG='\033[48;5;135m'     # Background color (purple)
WHITE='\033[97m'
BOLD='\033[1m'
RESET='\033[0m'

# Build padded banner line with project title
PAD_LEN=20
LEFT_PAD=$(printf "%${PAD_LEN}s" | tr ' ' '█')
RIGHT_PAD=$(printf "%${PAD_LEN}s" | tr ' ' '█')
printf "${COLOR}${LEFT_PAD}${COLOR_BG}${WHITE}${BOLD} My Project ${RESET}${COLOR}${RIGHT_PAD}${RESET}\n"

# Pass stdin through to the global statusline
echo "$input" | ~/.claude/statusline-command.sh
```

### Make it executable

```bash
chmod +x <project>/.claude/statusline-command.sh
```

### What it looks like

```
████████████████████ My Project ████████████████████
📁 my-project | 🌿 feat/my-branch
[24% 48.2k/200k] | $32.10 | 850k tokens | Opus 4.6
███████░░░░░░░░░░░░░░░░░░░░░░░
```

### Customization ideas

Change the banner color per project to visually distinguish them:

| Color          | `COLOR` code           | `COLOR_BG` code        |
|----------------|------------------------|------------------------|
| Purple         | `\033[38;5;135m`       | `\033[48;5;135m`       |
| Blue           | `\033[38;5;33m`        | `\033[48;5;33m`        |
| Green          | `\033[38;5;35m`        | `\033[48;5;35m`        |
| Orange         | `\033[38;5;208m`       | `\033[48;5;208m`       |
| Red            | `\033[38;5;196m`       | `\033[48;5;196m`       |
| Cyan           | `\033[38;5;44m`        | `\033[48;5;44m`        |
| Pink           | `\033[38;5;205m`       | `\033[48;5;205m`       |
| Gold           | `\033[38;5;220m`       | `\033[48;5;220m`       |

You can also adjust `PAD_LEN` to make the banner wider or narrower.


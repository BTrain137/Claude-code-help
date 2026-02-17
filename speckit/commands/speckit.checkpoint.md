---
description: Validate checkpoint criteria by analyzing tasks.md progress, running tests, and using browser automation
handoffs:
  - label: Continue Implementation
    agent: speckit.autorun
    prompt: Continue to the next task
    send: true
  - label: Fix Issues
    agent: 11-speckit.implement
    prompt: Fix the checkpoint validation failures
    send: false
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

---

## Checkpoint Validation Command

This command analyzes the current `tasks.md` progress, identifies the most recently completed checkpoint, and runs comprehensive validation to ensure all acceptance criteria are met.

---

## Phase 1: Detect Current Progress

### Step 1.1: Locate and Parse tasks.md

Find the active feature's tasks file:

```bash
# Auto-detect feature from git branch or find most recent
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [[ "$BRANCH" =~ ^([0-9]{3})- ]]; then
    FEATURE_NUM="${BASH_REMATCH[1]}"
else
    FEATURE_NUM=$(ls -d specs/[0-9]*/ 2>/dev/null | tail -1 | grep -oE '[0-9]{3}' || echo "001")
fi

# Find tasks.md
TASKS_FILE=$(ls specs/${FEATURE_NUM}*/tasks.md 2>/dev/null | head -1)
```

Read the tasks.md file to analyze progress.

### Step 1.2: Extract Progress Metrics

Parse tasks.md and extract:

1. **Completed tasks**: All lines matching `- [x]` or `- [X]` with task ID (e.g., `T001`)
2. **Pending tasks**: All lines matching `- [ ]` with task ID
3. **Last completed task**: The highest numbered completed task
4. **Current phase**: Which phase contains the last completed task

**Output format**:
```
📊 PROGRESS SUMMARY
═══════════════════════════════════════════════════════
  Total Tasks:      74
  Completed:        23  (31%)
  Remaining:        51  (69%)
  Last Completed:   T023
  Current Phase:    Phase 3: User Story 1 — Responsive Output
═══════════════════════════════════════════════════════
```

### Step 1.3: Identify Checkpoints

Parse tasks.md for all `**Checkpoint**:` lines and map them to the last task in each phase:

| Phase | Last Task | Checkpoint Description | Status |
|-------|-----------|------------------------|--------|
| Phase 1 | T002 | Foundation ready | ✅ Passed |
| Phase 2 | T012 | Foundation ready - user story implementation can begin | ✅ Passed |
| Phase 3 | T023 | Core responsive CSS generation works | 🎯 Current |
| Phase 4 | T038 | Class-based CSS, validation catches violations | ⏳ Pending |
| ... | ... | ... | ... |

**Determine current checkpoint**:
- Find the checkpoint whose "Last Task" matches the last completed task OR is the most recent completed checkpoint
- This is the checkpoint we need to validate

---

## Phase 2: Run Pre-Validation Checks

### Step 2.1: TypeScript Compilation Check

```bash
npx tsc --noEmit
```

**Expected**: Exit code 0 with no errors

**Report**:
```
🔧 TypeScript Compilation
   Status: ✅ PASS (no type errors)
   # OR
   Status: ❌ FAIL
   Errors:
     - src/server/css/generator.ts:45 - Type 'string' is not assignable to type 'number'
     - src/lib/ir/types.ts:120 - Property 'sizing' does not exist on type 'IRElement'
```

### Step 2.2: Lint Check

```bash
npm run lint
```

**Expected**: Exit code 0 with no errors

**Report**:
```
📝 ESLint Check
   Status: ✅ PASS (no lint errors)
   # OR
   Status: ⚠️ WARNINGS (2 warnings, 0 errors)
   # OR
   Status: ❌ FAIL (5 errors)
```

### Step 2.3: Unit Tests

```bash
npm run test:run
```

**Expected**: All tests pass

**Report**:
```
🧪 Unit Tests
   Status: ✅ PASS (42 tests passed)
   Duration: 3.2s
   # OR
   Status: ❌ FAIL (40 passed, 2 failed)
   Failed Tests:
     - tests/chains/css-generator.test.ts > generateCSS > should output responsive styles
     - tests/chains/ir-to-liquid.test.ts > buildTemplate > should include style block
```

---

## Phase 3: Checkpoint-Specific Validation

Based on the detected checkpoint, execute the appropriate validation suite:

### Checkpoint Validation Matrix

| Checkpoint | Validation Suite |
|------------|------------------|
| Phase 1/2: Foundation ready | App compiles, basic structure exists |
| Phase 3: Core responsive CSS | Generate Liquid → verify CSS output |
| Phase 4: Class-based CSS | Verify no inline styles, <style> block present |
| Phase 5: Theme-friendly CSS | Verify CSS variables exist |
| Phase 6: Preview QA | Test viewport preset buttons |
| Phase 7: Tests complete | All test suites pass |
| Phase 8: Polish complete | Full build succeeds |

---

## Phase 4: Browser Validation (Frontend Checkpoints)

### Step 4.1: Ensure Dev Server is Running

Check if the dev server is running:

```bash
# Check if port 3000 is in use
lsof -i :3000 | grep LISTEN
```

If NOT running:
1. Start the dev server in background: `npm run dev &`
2. Wait for server to be ready (poll `http://localhost:3000` until 200 response)
3. Maximum wait: 30 seconds

### Step 4.2: Browser Automation Validation

Use the browser MCP tools to validate frontend functionality:

#### Foundation / App Loads Checkpoint
```
1. browser_navigate("http://localhost:3000")
2. browser_snapshot() → verify page structure loads
3. browser_console_messages() → verify no critical errors
4. browser_take_screenshot({ filename: "checkpoints/foundation-{timestamp}.png" })
```

#### US1: Layer Tree / URL Input Checkpoint
```
1. browser_navigate("http://localhost:3000")
2. browser_snapshot() → find URL input field (ref)
3. browser_type({ ref: "input_ref", text: "https://www.figma.com/design/test/File?node-id=1-2" })
4. browser_click({ ref: "submit_button_ref" })
5. browser_wait_for({ time: 3 }) → wait for API response
6. browser_snapshot() → verify layer tree component appears
7. browser_take_screenshot({ filename: "checkpoints/us1-layer-tree-{timestamp}.png" })
```

#### US2: Generate Liquid Checkpoint
```
1. Complete US1 steps
2. browser_snapshot() → find "Generate" button
3. browser_click({ ref: "generate_button_ref" })
4. browser_wait_for({ text: "{% schema %}" }) → wait for Liquid output
5. browser_snapshot() → verify output panel shows Liquid code
6. browser_evaluate({ function: "() => document.querySelector('.liquid-output')?.textContent || ''" })
   → Verify contains: {% schema %}, <div, </section>
7. browser_take_screenshot({ filename: "checkpoints/us2-liquid-output-{timestamp}.png" })
```

#### Responsive CSS Checkpoint (Phase 3)
```
1. Generate Liquid (US2 steps)
2. browser_evaluate({ function: "() => document.querySelector('.liquid-output')?.textContent || ''" })
   → Verify CSS contains:
     - <style> block present
     - rem units (not just px)
     - clamp() for typography
     - max-width with 100% pattern
3. browser_resize({ width: 375, height: 667 }) → mobile
4. browser_snapshot() → verify no horizontal overflow
5. browser_take_screenshot({ filename: "checkpoints/responsive-375px-{timestamp}.png" })
6. browser_resize({ width: 768, height: 1024 }) → tablet
7. browser_take_screenshot({ filename: "checkpoints/responsive-768px-{timestamp}.png" })
8. browser_resize({ width: 1280, height: 800 }) → desktop
9. browser_take_screenshot({ filename: "checkpoints/responsive-1280px-{timestamp}.png" })
```

#### Class-Based CSS Checkpoint (Phase 4)
```
1. Generate Liquid
2. browser_evaluate({ function: "() => document.querySelector('.liquid-output')?.textContent || ''" })
   → Verify:
     - NO inline style="..." attributes (except Liquid {{ }})
     - <style> block at top
     - BEM-like classnames (e.g., .section-hero__title)
     - CSS selectors are scoped (start with .section-)
3. browser_take_screenshot({ filename: "checkpoints/us2-class-based-{timestamp}.png" })
```

#### Theme-Friendly CSS Variables Checkpoint (Phase 5)
```
1. Generate Liquid
2. browser_evaluate({ function: "() => document.querySelector('.liquid-output')?.textContent || ''" })
   → Verify CSS contains:
     - --section-max-width
     - --section-padding-x
     - --section-padding-y
     - var(--section-*) references
3. browser_take_screenshot({ filename: "checkpoints/us3-css-variables-{timestamp}.png" })
```

#### Preview QA / Viewport Presets Checkpoint (Phase 6)
```
1. Generate Liquid
2. browser_snapshot() → find viewport preset buttons (mobile/tablet/desktop)
3. browser_click({ ref: "mobile_preset_ref" })
4. browser_snapshot() → verify preview iframe resized to ~375px
5. browser_click({ ref: "tablet_preset_ref" })
6. browser_snapshot() → verify preview iframe resized to ~768px
7. browser_click({ ref: "desktop_preset_ref" })
8. browser_snapshot() → verify preview iframe resized to ~1280px
9. browser_take_screenshot({ filename: "checkpoints/us4-viewport-presets-{timestamp}.png" })
```

### Step 4.3: Verify No Console Errors

```
browser_console_messages()
```

**Acceptable**: info, log, warn messages  
**Failure**: Any error messages (excluding expected API errors with test URLs)

---

## Phase 5: Generate Report

### Success Report
```
╔══════════════════════════════════════════════════════════════════╗
║                    ✅ CHECKPOINT PASSED                          ║
╠══════════════════════════════════════════════════════════════════╣
║  Checkpoint: Core responsive CSS generation works                ║
║  Phase:      Phase 3: User Story 1 — Responsive Output           ║
║  Tasks:      T013-T023 (11 tasks completed)                      ║
╚══════════════════════════════════════════════════════════════════╝

📋 Pre-Validation Results
   ├─ TypeScript:  ✅ No errors
   ├─ Lint:        ✅ No errors
   └─ Unit Tests:  ✅ 42/42 passed

🌐 Browser Validation Results
   ├─ App Loads:        ✅ Page renders correctly
   ├─ Responsive 375px: ✅ No horizontal overflow
   ├─ Responsive 768px: ✅ Layout adapts correctly
   └─ Responsive 1280px:✅ Full desktop layout

📸 Evidence
   ├─ checkpoints/foundation-20260107-143022.png
   ├─ checkpoints/responsive-375px-20260107-143025.png
   ├─ checkpoints/responsive-768px-20260107-143027.png
   └─ checkpoints/responsive-1280px-20260107-143029.png

🎯 Next Steps
   Continue to Phase 4: User Story 2 — Maintainable CSS
   Next task: T024 - Create nodeIdToClassSuffix sanitizer
   
   Run: /speckit.autorun to continue implementation
```

### Failure Report
```
╔══════════════════════════════════════════════════════════════════╗
║                    ❌ CHECKPOINT FAILED                          ║
╠══════════════════════════════════════════════════════════════════╣
║  Checkpoint: Core responsive CSS generation works                ║
║  Phase:      Phase 3: User Story 1 — Responsive Output           ║
║  Failures:   3 issues detected                                   ║
╚══════════════════════════════════════════════════════════════════╝

📋 Pre-Validation Results
   ├─ TypeScript:  ✅ No errors
   ├─ Lint:        ⚠️ 2 warnings
   └─ Unit Tests:  ❌ 40/42 passed (2 failed)

🔴 Failed Validations

1. Unit Test Failure
   ─────────────────────────────────────────────────────────
   File: tests/chains/css-generator.test.ts
   Test: generateCSS > should output clamp() for large fonts
   Expected: CSS to contain "clamp("
   Actual: CSS contains only "px" values
   
   Fix: Update pxToFluidTypography() to use clamp() for fonts ≥24px

2. Browser Validation Failure
   ─────────────────────────────────────────────────────────
   Check: Responsive 375px width
   Expected: No horizontal scrollbar
   Actual: Horizontal overflow detected
   Screenshot: checkpoints/responsive-375px-20260107-143025.png
   
   Fix: Review FIXED constraint mapping - ensure max-width: 100%

3. CSS Content Validation Failure
   ─────────────────────────────────────────────────────────
   Check: CSS uses rem units
   Expected: Typography uses rem or clamp()
   Actual: Only px values found in output
   
   Fix: Ensure generateCSS calls pxToFluidTypography for font sizes

📸 Evidence
   └─ checkpoints/failure-responsive-375px-20260107-143025.png

🔧 Debug Steps
   1. Review failed test output: npm run test:run -- --reporter=verbose
   2. Check screenshot for visual issues
   3. Manually inspect generated CSS in browser devtools
   4. Review src/server/css/generator.ts lines 45-80

⚠️  Fix all issues before continuing with /speckit.autorun
```

---

## Checkpoint Detection Logic (Detailed)

To determine which checkpoint to validate:

```
1. Parse tasks.md line by line
2. Track current_phase and last_task_in_phase
3. When encountering "- [x] TXXX" → mark as completed
4. When encountering "**Checkpoint**:" → map to last_task_in_phase
5. After parsing:
   - Find highest completed task number (e.g., T023)
   - Find the checkpoint whose last_task <= highest completed
   - That's the checkpoint to validate
```

**Example with tasks.md state**:
```
Phase 2: - [x] T010, - [x] T011, - [x] T012
         **Checkpoint**: Foundation ready
Phase 3: - [x] T013, - [x] T014, ... - [x] T023
         **Checkpoint**: Core responsive CSS works
Phase 4: - [ ] T024, - [ ] T025, ...
         **Checkpoint**: Class-based CSS
```

**Result**: Last completed = T023 → Checkpoint = "Core responsive CSS works"

---

## Manual Fallback

If browser automation is unavailable:

1. Open http://localhost:3000 manually
2. Follow the checkpoint-specific validation steps
3. Take manual screenshots
4. Verify console has no errors (F12 → Console tab)
5. Report results based on observations

---

## Environment Requirements

- Node.js 18+ and npm
- `npm run dev` starts the app on port 3000
- Browser MCP tools OR manual browser available
- `checkpoints/` directory for screenshots (auto-created if missing)
- For Figma API tests: valid FIGMA_ACCESS_TOKEN (or expect mock errors)

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `/speckit.checkpoint` | Validate most recently completed checkpoint |
| `/speckit.checkpoint T023` | Validate checkpoint ending at T023 |
| `/speckit.checkpoint "responsive"` | Validate checkpoint matching keyword |
| `/speckit.checkpoint --verbose` | Show detailed browser interaction logs |

---

## Important Notes

1. **Always verify tests pass BEFORE browser validation** - failing tests often cause browser failures
2. **Take screenshots as evidence** - helps debug failures and proves completion
3. **Check console messages** - hidden errors can cause subtle bugs
4. **Test at all viewport sizes** for responsive checkpoints
5. **Create checkpoints/ directory** if missing before taking screenshots

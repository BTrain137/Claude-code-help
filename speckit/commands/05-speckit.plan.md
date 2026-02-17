---
description: Execute the implementation planning workflow using the plan template to generate design artifacts.
handoffs: 
  - label: Create Tasks
    agent: 06-speckit.tasks
    prompt: Break the plan into tasks
    send: true
  - label: Create Checklist
    agent: 08-speckit.checklist
    prompt: Create a checklist for the following domain...
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Outline

### Step 0: Determine Input Type

The `$ARGUMENTS` can be either:

1. **A file path** (e.g., `speckit-helpers/006-feature/02-speckit-plan-feature.md`) - Read the plan input document and use its content as the planning context
2. **Tech stack description** (original behavior) - Use current branch context
3. **Empty** - Use current branch context with auto-detected tech stack

**Detection logic**:
- If `$ARGUMENTS` ends with `.md` and the file exists → read the file content as plan input
- Otherwise → treat as tech stack description or use current branch

**If file path provided**:
1. Read the file content (the `02-*.md` plan input document)
2. Extract the feature directory name from the path (e.g., `006-feature`)
3. Locate the corresponding `specs/006-feature/` directory (create if needed)
4. Use the plan input document's Technical Context, Architecture Decisions, and other sections as the basis for generating formal artifacts
5. **ALWAYS run the "NEEDS CLARIFICATION" process** - Review the plan input for any gaps, ambiguities, or potential issues. Even if decisions seem complete, validate them with the user before proceeding.
6. After clarifications are resolved, generate: `plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**If no file path provided**:
- Continue with the original flow below

### Original Flow (when no file path provided)

1. **Setup**: Run `.specify/scripts/bash/setup-plan.sh --json` from repo root and parse JSON for FEATURE_SPEC, IMPL_PLAN, SPECS_DIR, BRANCH. For single quotes in args like "I'm Groot", use escape syntax: e.g 'I'\''m Groot' (or double-quote if possible: "I'm Groot").

2. **Load context**: Read FEATURE_SPEC and `.specify/memory/constitution.md`. Load IMPL_PLAN template (already copied).

3. **Execute plan workflow**: Follow the structure in IMPL_PLAN template to:
   - Fill Technical Context (mark unknowns as "NEEDS CLARIFICATION")
   - Fill Constitution Check section from constitution
   - Evaluate gates (ERROR if violations unjustified)
   - Phase 0: Generate research.md (resolve all NEEDS CLARIFICATION)
   - Phase 1: Generate data-model.md, contracts/, quickstart.md
   - Phase 1: Update agent context by running the agent script
   - Re-evaluate Constitution Check post-design

4. **Stop and report**: Command ends after Phase 2 planning. Report branch, IMPL_PLAN path, and generated artifacts.

## Phases

### Phase 0: Outline & Research

1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:

   ```text
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

### Phase 1: Design & Contracts

**Prerequisites:** `research.md` complete

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Agent context update**:
   - Run `.specify/scripts/bash/update-agent-context.sh claude`
   - These scripts detect which AI agent is in use
   - Update the appropriate agent-specific context file
   - Add only new technology from current plan
   - Preserve manual additions between markers

**Output**: data-model.md, /contracts/*, quickstart.md, agent-specific file

## Key rules

- Use absolute paths
- ERROR on gate failures or unresolved clarifications

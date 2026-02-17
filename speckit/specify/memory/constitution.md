<!--
================================================================================
SYNC IMPACT REPORT
================================================================================
Version change: 1.1.0 → 2.0.0 (MAJOR - complete principle redefinition for domain)

Modified Principles:
  - I. Code Quality → I. Fast Iteration (emphasis on vertical slices, velocity)
  - II. Architecture → II. Project Structure (specific Next.js App Router layout)
  - III. Lightweight Testing → VI. Lightweight Testing (fixture-based for IR/Liquid)
  - V. AI Workflow → IV. LangChain Orchestration (composable chains pattern)

Added Principles:
  - III. Design IR (stable intermediate representation between Figma and Liquid)
  - V. Shopify Compatibility (OS 2.0 sections with schema, settings, blocks)
  - VII. Deterministic Replay (store IR + Liquid for debug/replay)
  - VIII. Security (env-only secrets, no logging)
  - IX. Server-Side AI (LLM logic in Node runtime only)

Removed Principles:
  - IV. User Experience (UI-specific; not primary focus for converter tool)

Added Sections:
  - Design IR Schema (under Technology Stack)
  - Chain Pipeline Structure (under LangChain Orchestration)

Removed Sections: None

Templates Status:
  ✅ .specify/templates/plan-template.md - Compatible (Constitution Check section exists)
  ✅ .specify/templates/spec-template.md - Compatible (priority-based stories align with vertical slices)
  ✅ .specify/templates/tasks-template.md - Compatible (fixture test tasks, Phase 1 lightweight testing)

Follow-up TODOs: None

================================================================================
-->

# Figma to Liquid Constitution

## Core Principles

### I. Fast Iteration

Development MUST prioritize velocity and small, shippable increments over upfront perfection.

- **Vertical Slices**: Features MUST be delivered as thin end-to-end slices (Figma input → IR → Liquid output)
- **Minimal Over-Engineering**: Implement only what is needed now; avoid speculative abstractions
- **YAGNI**: Do NOT build features, helpers, or infrastructure for hypothetical future needs
- **Pragmatic Shortcuts**: Temporary solutions are acceptable when they unblock progress; document with `TODO`
- **Refactor Later**: Clean up after the feature works, not before

**Rationale**: Speed-to-learning beats polish. Working software reveals requirements faster than planning.

### II. Project Structure

Code MUST follow a strict directory layout that separates concerns and enables clean bundling.

- **App Router**: Use Next.js App Router (`app/`) for all routes and pages
- **Server Code**: All server-only logic MUST live under `src/server/*`
  - LLM orchestration, Figma API calls, file I/O
- **Shared Logic**: Pure TypeScript utilities and types MUST live under `src/lib/*`
  - Design IR types, Liquid templates, validation helpers
- **Client Components**: React components MUST live under `src/components/*` or colocated in `app/`
- **No Barrel Exports**: Avoid `index.ts` re-exports that can bloat client bundles

```text
src/
├── server/          # Server-only: LLM chains, Figma client, file ops
│   ├── chains/      # LangChain pipelines
│   ├── figma/       # Figma API integration
│   └── liquid/      # Liquid generation logic
├── lib/             # Shared: types, pure functions, templates
│   ├── ir/          # Design IR types and validators
│   ├── templates/   # Liquid template strings
│   └── utils/       # Pure utility functions
└── components/      # Client React components (if needed)
```

**Rationale**: Clear boundaries prevent accidental client-side bundling of server code and API secrets.

### III. Design IR

All Figma-to-Liquid conversion MUST flow through a stable intermediate representation.

- **Single Source of Truth**: The Design IR is the ONLY input to Liquid generation
- **Figma Decoupling**: Parsing Figma → IR MUST be separate from IR → Liquid generation
- **Schema Stability**: IR schema changes MUST be versioned and backward-compatible when possible
- **Serializable**: IR MUST be JSON-serializable for storage and debugging
- **Minimal Fields**: IR SHOULD contain only data needed for Liquid generation—no Figma metadata leakage

```typescript
// Example IR structure (src/lib/ir/types.ts)
interface DesignIR {
  version: string;
  sectionName: string;
  elements: IRElement[];
  settings: IRSetting[];
  blocks?: IRBlock[];
}
```

**Rationale**: A stable IR enables independent iteration on parsing and generation, plus deterministic replay.

### IV. LangChain Orchestration

AI workflows MUST use small, composable LangChain chains with clear pipeline stages.

- **Pipeline Pattern**: Chains MUST follow the structure: `parse → map → generate → validate`
- **Small Chains**: Each chain SHOULD do ONE thing (parse Figma, map to IR, generate Liquid, validate output)
- **Composable**: Chains MUST be composable via `RunnableSequence` or similar
- **Server-Only**: All LangChain imports and invocations MUST be in `src/server/*`
- **No Client Bundling**: LangChain code MUST NEVER appear in client bundles
- **Structured Output**: Use structured output parsing (Zod schemas) for reliable IR extraction

```typescript
// Example pipeline structure
const pipeline = RunnableSequence.from([
  parseFigmaChain,      // Figma JSON → structured data
  mapToIRChain,         // Structured data → Design IR
  generateLiquidChain,  // Design IR → Liquid section
  validateLiquidChain,  // Liquid → validation result
]);
```

**Rationale**: Composable chains enable debugging at each stage and swapping individual steps.

### V. Shopify Compatibility

Generated Liquid MUST be valid Shopify 2.0 theme sections.

- **Section Structure**: Output MUST include `{% schema %}` block with proper JSON
- **Settings Array**: Schema MUST define `settings` array for customizer inputs
- **Blocks Support**: Schema MUST include `blocks` array when repeatable elements are detected
- **Presets**: Schema SHOULD include `presets` for theme editor discoverability
- **Valid Liquid**: Output MUST use valid Liquid syntax (objects, filters, tags)
- **No External Dependencies**: Sections MUST NOT require external JavaScript or build steps

```liquid
{% comment %} Example section output structure {% endcomment %}
<section class="section-{{ section.id }}">
  {{ section.settings.heading }}
</section>

{% schema %}
{
  "name": "Section Name",
  "settings": [...],
  "blocks": [...],
  "presets": [...]
}
{% endschema %}
```

**Rationale**: Shopify theme compatibility is non-negotiable for production use.

### VI. Lightweight Testing

Testing MUST enable rapid iteration without becoming a bottleneck.

- **Fixture-Based**: Tests for IR parsing and Liquid generation MUST use fixture files
- **No Heavy E2E**: End-to-end browser tests are NOT required for Phase 1
- **Snapshot Tests**: Liquid output SHOULD use snapshot testing for regression detection
- **Test on Demand**: Add tests when bugs are discovered or for high-risk changes
- **Fast Execution**: Test suite MUST complete in under 30 seconds

**Test Structure**:

```text
tests/
├── fixtures/           # Input Figma JSON and expected IR/Liquid
│   ├── simple-hero/
│   │   ├── input.json      # Figma frame data
│   │   ├── expected-ir.json
│   │   └── expected.liquid
│   └── ...
├── ir/                 # IR parsing tests
└── liquid/             # Liquid generation tests
```

**Rationale**: Fixture tests are fast, deterministic, and document expected behavior.

### VII. Deterministic Replay

All conversion runs MUST produce storable artifacts for debugging and replay.

- **Store IR**: Every conversion MUST persist the Design IR to disk or database
- **Store Output**: Every conversion MUST persist the generated Liquid output
- **Timestamps**: Artifacts MUST include generation timestamp and input hash
- **Replayable**: Given stored IR, Liquid generation MUST produce identical output
- **Debug Mode**: A debug flag SHOULD enable verbose logging of pipeline stages

**Rationale**: Deterministic replay enables debugging, regression testing, and auditing.

### VIII. Security

Secrets and credentials MUST be handled with zero-trust discipline.

- **Env Vars Only**: Figma tokens, OpenAI keys, and all API credentials MUST be in environment variables
- **Never Log Secrets**: Secrets MUST NEVER appear in logs, error messages, or stored artifacts
- **No Client Exposure**: Secrets MUST NEVER be accessible from client-side code
- **Validation**: Server code SHOULD validate required env vars at startup
- **.env.local**: Local secrets MUST be in `.env.local` (gitignored)

**Rationale**: A single logged secret can compromise the entire project.

### IX. Server-Side AI

All LLM and LangChain logic MUST execute on the server, never in client bundles.

- **Node Runtime**: LLM calls MUST use Next.js API routes or Server Actions with Node runtime
- **Edge Incompatible**: LangChain MAY require Node-only features; do NOT use Edge runtime
- **Route Handlers**: Use `app/api/` route handlers for LLM endpoints
- **No Dynamic Imports**: Do NOT use dynamic imports to defer LLM code to client
- **Bundle Verification**: Periodically verify client bundle does NOT include LangChain

**Rationale**: LLM calls require API keys that must never reach the browser.

## Technology Stack

This section defines the approved technology choices for the project.

**Frontend & Framework**:

- **Framework**: Next.js 15+ with App Router
- **Language**: TypeScript 5+
- **UI Library**: React 19+
- **Styling**: Tailwind CSS 4+

**AI & Orchestration**:

- **LLM Framework**: LangChain.js (server-side only)
- **LLM Provider**: OpenAI (configurable)
- **Pipeline Pattern**: parse → map → generate → validate
- **Structured Output**: Zod schemas for IR extraction

**Shopify Output**:

- **Target**: Shopify 2.0 theme sections
- **Format**: Liquid templates with JSON schema blocks
- **Compatibility**: Dawn theme baseline

**Infrastructure**:

- **Package Manager**: npm
- **Linting**: ESLint with Next.js configuration
- **Deployment**: Vercel
- **Runtime**: Node.js (NOT Edge)

New dependencies SHOULD be added only when they provide clear value and do not conflict with existing choices.

## Development Workflow

This section defines how code moves from development to production.

- **Branch Strategy**: Feature branches off main; merge via pull request
- **Vertical Slices**: Each PR SHOULD deliver a thin end-to-end slice when possible
- **Commit Messages**: Use conventional commit format (feat:, fix:, docs:, chore:)
- **Local Development**: `npm run dev` starts the development server at localhost:3000
- **Build Verification**: `npm run build` MUST succeed before merge
- **Linting**: `npm run lint` MUST pass before merge
- **Fixture Tests**: Run `npm test` for IR and Liquid fixture tests

## Governance

This constitution establishes the foundational principles for the Figma to Liquid project.

- **Supremacy**: This constitution supersedes conflicting guidance in other documents
- **Amendments**: Changes to principles require documentation of rationale and version increment
- **Compliance**: Code reviews SHOULD verify adherence to these principles
- **Flexibility**: Principles guide decisions but SHOULD NOT block pragmatic solutions when justified
- **Versioning Policy**:
  - MAJOR: Backward-incompatible principle changes or removals
  - MINOR: New principles added or existing ones materially expanded
  - PATCH: Clarifications, wording improvements, non-semantic refinements

**Version**: 2.0.0 | **Ratified**: 2025-12-30 | **Last Amended**: 2025-12-30

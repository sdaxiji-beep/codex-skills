# Phase Plan

Last updated: 2026-03-24

## Current execution status

- Phase 1 core productization: completed baseline and stable in regression.
- Phase 2 Stage 2C (parser-backed primary verdict with rollback switch): completed.
- Phase 2 Stage 2D checkpoint-1 (mismatch governance + diagnostic quality assertions): completed and regression-green.
- Phase 2 Stage 2D checkpoint-2 (budgeted mismatch drift guardrails): completed and regression-green.
- Phase 2 Stage 2E checkpoint-1 (WXML structure semantics + constructor parity): completed and regression-green.
- Phase 2 Stage 2E checkpoint-2 (WXML directive semantics coverage): completed in speed-mode validation (Layer0 + focused + fast).
- Phase 2 Stage 2E checkpoint-3 (severity policy shaping for AST hybrid promotion): completed in speed-mode validation (Layer0 + focused + fast).
- Phase 2 Stage 2E checkpoint-4 (page/component policy parity consolidation via shared AST policy module): completed in speed-mode validation (Layer0 + focused + fast).
- Phase 2 Stage 2E checkpoint-5 (component severity-policy coverage expansion): completed in speed-mode validation (Layer0 + focused + fast).
- Phase 2 release-checkpoint (full regression) completed: 85/85.
- Phase 2 Stage 2F checkpoint-1 (shared AST helper consolidation for counts/message formatting): completed in speed-mode validation (Layer0 + focused + fast).
- Phase 2 Stage 2F checkpoint-2 (page/component artifact parity regression coverage): completed in speed-mode validation (Layer0 + focused + fast).
- Phase 2 close-out full checkpoint completed: 87/87.
- Phase 3 checkpoint-1 started and completed:
  - unified MCP tool boundary script added (`scripts\wechat-mcp-tool-boundary.ps1`)
  - focused MCP boundary contract test added (`scripts\test-wechat-mcp-tool-boundary-contract.ps1`)
  - minimal Claude integration guide added (`CLAUDE.md`)
- Phase 3 checkpoint-2 completed:
  - boundary contract self-describe operation added (`describe_contract`)
  - boundary interface version contract added (`mcp_tool_boundary_v1`)
  - apply exit-code to gate-status mapping standardized in boundary response
  - focused failure-path contract test added (`scripts\test-wechat-mcp-tool-boundary-failure-contract.ps1`)
- Phase 3 checkpoint-3 (part 1) completed:
  - boundary file-input contract test added (`scripts\test-wechat-mcp-tool-boundary-file-input-contract.ps1`)
- Phase 3 checkpoint-3 (part 2) completed:
  - boundary error-input contract test added (`scripts\test-wechat-mcp-tool-boundary-error-contract.ps1`)
  - MCP boundary contract doc added (`MCP_BOUNDARY_CONTRACT.md`)
  - validation confirmed: guard-check `142`, fast `64/64`
- Phase 3 checkpoint-4 (part 1) completed:
  - boundary execution-profile operation added (`describe_execution_profile`)
  - focused profile contract test added (`scripts\test-wechat-mcp-tool-boundary-profile-contract.ps1`)
  - validation confirmed: guard-check `143`, fast `65/65`, full `92/92`
- Phase 3 checkpoint-4 (part 2) completed:
  - external-client boundary quickstart added to `README.md`
  - focused doc-sync regression added (`scripts\test-wechat-mcp-tool-boundary-doc-sync.ps1`)
  - validation confirmed: guard-check `144`, fast `66/66`
- Phase 3 checkpoint-4 (part 3) completed:
  - external client entrypoint map added (`EXTERNAL_CLIENT_ENTRYPOINTS.md`)
  - focused entrypoint-doc regression added (`scripts\test-external-client-entrypoints-doc.ps1`)
  - validation confirmed: guard-check `145`, fast `67/67`, full `94/94`
- Phase 3 checkpoint-5 (part 1) completed:
  - deploy config default moved to `config\local-release.config.json` with example config + ignore rule
  - release whitelist manifest/check added (`release-package.manifest.json`, `scripts\check-release-package.ps1`)
  - focused release package regression added (`scripts\test-release-package-candidate.ps1`)
  - focused external-client dry-run regression added (`scripts\test-external-client-boundary-dry-run.ps1`)
  - validation confirmed: guard-check `148`, fast `69/69`, full `96/96`
- Phase 3 checkpoint-5 (part 2) completed:
  - `specs/` removed from release package include surface
  - release package check now scans included files for rooted machine-specific paths
  - release-facing scripts/tests/examples switched from rooted local paths to repo-relative or generic placeholders where possible
  - validation confirmed: guard-check `148`, fast `69/69`
- Phase 3 checkpoint-5 (part 3) completed:
  - external-client payload contract docs now explicitly document `page_name`, `component_name`, and `append_pages`
  - focused payload doc regression added (`scripts\test-external-client-payload-contract-doc.ps1`)
  - boundary-only external-client release drill now passes for page write + app.json patch flow
  - validation confirmed: fast `70/70`, full `97/97`
- Current strategy in progress: Phase 3 MCP/client/platform decoupling (post-checkpoint-5 final release-candidate review).

## Goal

Turn this repo from a locally effective Codex workspace into a shareable, controlled WeChat Mini Program generation system with stronger validation, clearer product boundaries, and broader client compatibility.

The target is not "more templates". The target is:

1. natural language -> engineering action
2. controlled generation -> validate -> write
3. safe shared usage for other users
4. lower coupling to one client/runtime

## Phase 1 - Productize The Current Core

### Objective

Stabilize the current v1.1 workflow as a clear product surface before adding major new capabilities.

### Why this phase comes first

The repo already has the right architecture direction:

- page generation gate
- component generation gate
- append-only app.json patch flow
- preview-first release stance

What is still weak is product clarity and end-to-end proof, not feature count.

### Tasks

1. Add one explicit end-to-end integration path document and test flow:
   - natural language request
   - generate component
   - generate page
   - page uses component
   - app.json route patch
   - preview guard
   - upload/deploy guard
2. Tighten README opening structure:
   - what this repo is
   - what problem it solves
   - minimum path to first success
   - deeper architecture after that
3. Define support boundaries clearly:
   - supported: Windows + PowerShell + current Codex-style workflow
   - experimental: broader MCP/client reuse
   - not yet promised: cross-platform one-command flow
4. Align every public "safe/controlled/guarantee" statement with actual code behavior.

### Exit criteria

- a new user can understand the repo in under 5 minutes
- one documented end-to-end golden path is stable
- public docs and actual behavior do not drift

## Phase 2 - Upgrade Guardrails From Regex To Trusted Validation

### Objective

Strengthen Generation Gate from string matching to syntax-aware validation.

### Why this phase matters

Current regex guardrails are good enough for practical v1 usage, but not strong enough to justify harder safety claims long term.

### Tasks

1. Add AST-based JS validation:
   - parse page/component JS
   - validate allowed constructors and structure
   - detect forbidden browser/web APIs more reliably
2. Replace manual WXML structure checks with a parser-backed validation path.
3. Split validation severity:
   - hard fail
   - retryable fail
   - warning
4. Refactor shared validation logic so page/component/app patch validators reuse a common policy layer.

### Exit criteria

- JS validation is parser-based, not regex-only
- WXML validation is parser-based, not stack-only
- safety claims in docs can be stated more strongly without overclaiming

## Phase 3 - Decouple From One Client And One Platform

### Objective

Turn the repo into a reusable controlled-generation backend, not only a Codex-specific workspace.

### Why this phase comes after Phase 2

Broader distribution only makes sense after the validation core is strong enough to export.

### Tasks

1. Expose core validate/apply flows as MCP-friendly tool boundaries:
   - validate_bundle
   - apply_bundle
   - validate_component_bundle
   - apply_app_json_patch
2. Add a minimal Claude-oriented integration layer:
   - `CLAUDE.md`
   - explicit state-file usage
   - script entrypoint map
3. Start moving the core orchestration path to Node.js/TypeScript:
   - keep PowerShell compatibility where useful
   - remove Windows-only assumptions from the core path over time
4. Design a higher-level one-sentence entry flow so the user does not manually step through spec/apply stages in normal usage.

### Exit criteria

- core flows can be reused by MCP-capable clients
- Claude/Cursor-like clients can follow the repo with minimal translation
- PowerShell is no longer the only viable orchestration layer

## Priority Order

1. finish Phase 1 before adding more generation surface
2. finish the core of Phase 2 before making stronger public safety claims
3. start Phase 3 only after the validation core is strong enough to export

## What Not To Do Right Now

- do not add more templates just to increase feature count
- do not chase cross-platform parity before the current guardrails are strengthened
- do not expand deploy automation beyond the current preview-first guarded stance

## Immediate Next Step

Phase 2 Stage 2D starts with one concrete deliverable:

- add mismatch governance checks and artifact quality assertions so parser-first behavior stays stable release-over-release

# WeChat DevTools Control

This project turns natural-language requests into runnable WeChat mini program projects with guarded preview/deploy workflows.

## What this is

This is not just a prompt library or a template copier.

It is a controlled WeChat Mini Program generation workflow that separates:

- natural-language intent
- generated code payloads
- local validation gates
- disk write/apply execution

Any connected client that can call local scripts, including Codex, Claude-style clients, or Cursor-style clients, can use the same boundary contract without getting direct unrestricted write access to the project.

## What problems it solves

This repo is built to stop the common failure modes of LLM-driven Mini Program generation:

- invalid WXML such as HTML tags like `<div>`
- invalid JS such as browser-only APIs like `window`, `document`, `fetch`, or `axios`
- unsafe writes outside allowed page/component/app patch scopes
- partial output that is not structured enough for reliable apply/retry flows

## Core mechanism

The core model is:

1. The client generates a structured JSON bundle or patch.
2. The bundle goes through a local Generation Gate.
3. Only validated payloads are allowed to reach apply scripts.
4. External clients use one MCP-friendly boundary entry:
   - `scripts\wechat-mcp-tool-boundary.ps1`

This boundary gives external clients a stable contract for:

- `describe_contract`
- `describe_execution_profile`
- `validate_*`
- `apply_*`

That execution profile also defines retry behavior:

- retry automatically on `retryable_fail`
- stop on `hard_fail`
- fix input contract first on boundary `error`

## Quick handoff

From an external client point of view, the minimum path is:

1. Read `EXTERNAL_CLIENT_ENTRYPOINTS.md`
2. Build a valid JSON payload
3. Call `validate_*`
4. If validation passes, call `apply_*`
5. If apply returns `retryable_fail`, regenerate and retry

## What users can do

- One-command create flow: prompt -> project generation -> optional open -> optional preview
- Runtime doctor: check DevTools port/API, CLI path, and generated workspace health
- Generated project operations: list/open/preview/deploy guard/appid switch/upload dry-run
- Validation gates: `fast` and `full`

## Current baseline

- Layer 0 syntax check: pass (`148` scripts)
- `fast-gate`: `70/70`
- `full`: `97/97`
- focused shadow check: `test-generation-gate-ast-shadow.ps1` pass
- focused component shadow check: `test-generation-gate-component-ast-shadow.ps1` pass
- focused hybrid check: `test-generation-gate-ast-hybrid.ps1` pass
- focused component hybrid check: `test-generation-gate-component-ast-hybrid.ps1` pass
- focused default-on + rollback check: `test-generation-gate-ast-hybrid-default-and-rollback.ps1` pass
- focused component default-on + rollback check: `test-generation-gate-component-ast-hybrid-default-and-rollback.ps1` pass
- focused parser-backed hybrid check: `test-generation-gate-ast-hybrid-parser.ps1` pass (`shadow_parser=acorn`)
- focused severity-policy check: `test-generation-gate-ast-severity-policy.ps1` pass
- focused policy-parity check: `test-generation-gate-ast-policy-parity.ps1` pass
- focused component severity-policy check: `test-generation-gate-component-ast-severity-policy.ps1` pass
- focused policy-helper check: `test-generation-gate-ast-policy-helpers.ps1` pass
- focused artifact-parity check: `test-generation-gate-ast-artifact-parity.ps1` pass
- `full`: `96/96` (latest release-checkpoint run)

## Phase 3 checkpoint-1

- unified MCP-friendly boundary entry added:
  - `scripts\wechat-mcp-tool-boundary.ps1`
- supported operations:
  - `describe_contract`
  - `describe_execution_profile`
  - `validate_page_bundle`
  - `apply_page_bundle`
  - `validate_component_bundle`
  - `apply_component_bundle`
  - `validate_app_json_patch`
  - `apply_app_json_patch`
- focused boundary contract test:
  - `test-wechat-mcp-tool-boundary-contract.ps1`
- focused boundary failure-contract test:
  - `test-wechat-mcp-tool-boundary-failure-contract.ps1`
- focused boundary file-input contract test:
  - `test-wechat-mcp-tool-boundary-file-input-contract.ps1`
- focused boundary error-input contract test:
  - `test-wechat-mcp-tool-boundary-error-contract.ps1`
- focused boundary profile-contract test:
  - `test-wechat-mcp-tool-boundary-profile-contract.ps1`
- focused boundary/doc-sync test:
  - `test-wechat-mcp-tool-boundary-doc-sync.ps1`
- boundary response contract:
  - `interface_version = mcp_tool_boundary_v1`
  - apply result includes `gate_status` mapped from `exit_code`
- minimal Claude integration guide:
  - `CLAUDE.md`
- MCP boundary contract doc:
  - `MCP_BOUNDARY_CONTRACT.md`
- External client entrypoint map:
  - `EXTERNAL_CLIENT_ENTRYPOINTS.md`
- focused external-client entrypoint doc test:
  - `test-external-client-entrypoints-doc.ps1`
- focused external-client payload doc test:
  - `test-external-client-payload-contract-doc.ps1`
- focused external-client boundary dry-run test:
  - `test-external-client-boundary-dry-run.ps1`
- focused release-package candidate test:
  - `test-release-package-candidate.ps1`
- create + preview flow: available from one command entry
- Phase roadmap: see `PHASE_PLAN.md`
- Phase 1 golden path: see `GOLDEN_PATH.md`
- Phase 2 AST design: see `AST_VALIDATION_DESIGN.md`

## Phase 2A status

AST shadow mode is now scaffolded for both page and component generation gates:

- Node validator entrypoint: `scripts\validators\validate-bundle-ast.mjs`
- PowerShell gate remains the source of truth for verdicts
- shadow diagnostics are written to:
  - `artifacts\wechat-devtools\generation-gate\ast-shadow-latest.json`
  - `artifacts\wechat-devtools\generation-gate\component-ast-shadow-latest.json`
  - timestamped snapshots in the same folder

Current Stage 2A intent is comparison and telemetry only. Shadow diagnostics do not change `pass`, `retryable_fail`, or `hard_fail`.

Validation note:

- run `fast` and `full` sequentially (not in parallel) to avoid write-guard test interference.

## Stage 2B hybrid mode

Hybrid mapping is now default-on:

- AST diagnostics with `severity=error` are promoted into gate retryable errors by default
- rollback switch is available: set `WECHAT_AST_HYBRID_MODE=0` (or `false` / `off`) to disable AST promotion temporarily
- artifacts now include:
  - `hybrid_mode`
  - `promoted_error_count`

## Stage 2C parser-backed checkpoint

- parser-backed diagnostics are now verified in regression (real malformed JS parse path via `acorn`)
- parser-backed promotion is now default policy in both page and component gates
- rollback path is explicit and tested via `WECHAT_AST_HYBRID_MODE=0`

## Stage 2D mismatch governance checkpoint

- mismatch governance is now regression-covered for both page and component gates:
  - rollback mode (`WECHAT_AST_HYBRID_MODE=0`) keeps gate verdict pass and marks `shadow_mismatch=true`
  - default mode (env unset) promotes AST errors and marks `shadow_mismatch=false`
- diagnostics quality is now asserted in tests (`code`, `file`, `message`, `severity` fields must exist)
- budgeted drift guardrail is now active in regression:
  - `test-generation-gate-ast-mismatch-budget.ps1` enforces mismatch/diagnostic budgets for recent artifacts
  - default budgets: `WECHAT_AST_MISMATCH_BUDGET=0`, `WECHAT_AST_DIAGNOSTIC_ISSUE_BUDGET=0`

## Stage 2E parser coverage checkpoint

- WXML structure semantics are now parser-validated in AST layer:
  - `wxml_unmatched_close_tag`
  - `wxml_tag_mismatch`
  - `wxml_unclosed_tag`
- page/component constructor parity is now AST-validated:
  - `js_constructor_mismatch_page`
  - `js_constructor_mismatch_component`
- focused checks added:
  - `test-generation-gate-ast-wxml-semantics.ps1`
  - `test-generation-gate-ast-wxml-directive-semantics.ps1`
  - `test-generation-gate-ast-constructor-parity.ps1`
  - `test-generation-gate-ast-severity-policy.ps1`
  - `test-generation-gate-ast-policy-parity.ps1`
  - `test-generation-gate-ast-policy-helpers.ps1`
  - `test-generation-gate-ast-artifact-parity.ps1`
  - `test-generation-gate-component-ast-severity-policy.ps1`

Stage 2E severity policy shaping:

- hybrid promotion remains default-on and status contract unchanged
- promoted severities are now configurable through `WECHAT_AST_PROMOTED_SEVERITIES`
  - default: `error`
  - optional strict mode: `error,warn`
- test hook for policy verification: `WECHAT_AST_TEST_FORCE_WARNING=1`
- artifacts now include:
  - `promoted_severities`
  - `promoted_diagnostic_count`

## Quickstart (for other users)

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\\wechat.ps1")

# 1) Bootstrap workspace
Invoke-WechatBootstrap

# 2) Check local environment
Invoke-WechatDoctor

# 3) Create and preview from prompt
Invoke-WechatCreate `
  -Prompt "build a mood journal mini program" `
  -Open $false `
  -Preview $false
```

## Main commands

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\\wechat.ps1")

Invoke-WechatDoctor
Invoke-WechatCreate -Prompt "..."
Get-GeneratedProjectList
Invoke-GeneratedProjectOpen
Invoke-GeneratedProjectPreview
Invoke-GeneratedProjectDeployGuard
Invoke-GeneratedProjectSetAppId
Invoke-GeneratedProjectUpload -DryRun $true
```

## External client boundary quickstart

Use the MCP-friendly boundary script when integrating from Claude/Cursor/Gemini-style clients:

```powershell
# 1) Inspect interface contract
powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-tool-boundary.ps1 -Operation describe_contract

# 2) Inspect execution profile (retry/abort guidance)
powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-tool-boundary.ps1 -Operation describe_execution_profile

# 3) Validate payload from file
powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-tool-boundary.ps1 `
  -Operation validate_page_bundle `
  -JsonFilePath ".\.agents\tasks\bundle_page_home.json" `
  -TargetWorkspace (Get-Location).Path
```

## Safety defaults

- Generated projects are preview-first by default.
- `touristappid` projects are blocked from deploy/upload.
- Real release is allowed only after setting a real appid and passing guard checks.
- Recommended product policy: treat generated projects as preview-only unless the user explicitly switches to a real appid and chooses guarded upload.

## Next productization target

Phase 1 is now focused on one explicit end-to-end golden path:

- component generation
- page generation
- append-only app.json patch
- preview guard
- upload/deploy guard

See `GOLDEN_PATH.md` for the target workflow contract and acceptance criteria.

Focused contract check:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-golden-path-contract.ps1
```

Focused execution drill:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-golden-path-drill.ps1
```

## Package scope

Use `RELEASE_PACKAGE.md` as the packaging checklist before sharing this project with others.
Use `RELEASE_FINAL_ACTIONS.md` as the final go/no-go list before publishing a release candidate or public share.

Release-candidate package check:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\check-release-package.ps1
```

This check verifies both package manifest completeness and release-surface hygiene, including rooted machine-specific path leakage in manifest-included files.

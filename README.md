# WeChat DevTools Control

Current release candidate: `v2.1.0-rc.1`

This project turns natural-language requests into runnable WeChat mini program projects with guarded preview/deploy workflows.
Examples in this README use repo-relative paths so they work from any clone.

## Automated Workflow (Phase 5)

The repo now supports an internal automated workflow for generated/local projects:

- Natural Language
- `TaskSpec`
- translator
- bundle compiler
- boundary validate/apply
- acceptance checks
- acceptance-driven repair
- DevTools open/preview path

In short:

- Natural Language -> Auto Generate -> Validate -> Auto Repair -> DevTools Preview

This Phase 5 flow is currently an internal skills capability, not a public MCP contract.
It is intended to let local clients work through the structured pipeline instead of writing files directly.

See [P5_CLOSURE_SUMMARY.md](P5_CLOSURE_SUMMARY.md) for the finalized internal architecture, supported task families, and real-drill status.

## Registry-first Pipeline

The current internal generation stack is registry-first for migrated families:

- Natural Language
- `TaskSpec`
- translator
- bundle compiler
- `assets\registry.json` lookup
- boundary validate/apply
- acceptance checks
- acceptance-driven repair
- DevTools open/preview path

Registry-backed stable assets currently include:

- components: `cta-button`, `product-card`, `buy-button`, `food-item`, `cart-summary`
- page templates: `coupon-empty-state`, `product-listing`, `product-detail`, `food-order`, `food-checkout`

Current registry-first architecture:

- Natural Language
- `TaskSpec`
- translator
- bundle compiler
- `assets\registry.json`
- boundary validate/apply
- acceptance checks
- acceptance-driven repair
- DevTools open/preview path

Cross-page capability is now verified for internal flows:

- multi-page TaskSpec targets
- registry-backed page loading for more than one page
- app route registration for linked pages
- navigator-based jump validation

Legacy hardcoded generation paths remain in place only as fallback compatibility during migration.

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

## Under Development

The repo now has an internal natural-language execution chain that is not yet part of the public MCP contract:

- `TaskSpec` internal IR
- translator fallback
- bundle compiler
- execution bridge
- acceptance checks
- acceptance-driven repair loop

This internal path is currently used for generated product-task families such as:

- marketing empty-state pages
- product listing
- product detail
- food order / checkout flow

It is intended for guarded local/generated workflows first. It remains internal until the task semantics, recovery behavior, and real DevTools drill results are stable enough for public contract exposure.

Agent preference:

- prefer the `TaskSpec -> translator -> compiler -> executor -> acceptance -> repair` flow
- avoid direct file mutation when the structured task pipeline can express the change

## Validation tiers

The repo now has multiple validation layers, and they should not be confused:

- `GuardCheckOnly`: syntax and guard surface
- `test-diagnostics-focused.ps1`: diagnostics/detect/repair contracts
- `fast`: core local regression
- `full`: broader integration regression

GitHub CI currently covers only the repo-safe guard and diagnostics-focused layers.
Local Windows + WeChat DevTools validation is still required for the higher tiers and for any real preview/deploy confirmation.

GitHub PR checks:

- `GuardCheckOnly`
- `test-diagnostics-focused.ps1`

Recommended repository ruleset / required checks:

- `ci-minimal / guardrails`
- `ci-diagnostics / diagnostics-focused`

Local-only validation:

- `fast`
- `full`
- real DevTools preview/deploy drills

## Local vs CI

| Check | GitHub CI | Local Windows + DevTools |
| --- | --- | --- |
| `GuardCheckOnly` | Yes | Yes |
| `test-diagnostics-focused.ps1` | Yes | Yes |
| `fast` | No | Yes |
| `full` | No | Yes |
| Real preview / deploy drills | No | Yes |
| Release candidate gating | Public-safe only | Required |

Required local validation for release candidates remains `fast`, `full`, and real preview/deploy drills on a Windows + WeChat DevTools machine.
This matrix is a sharing guide, not a contract change; the stable boundary remains the documented scripts and operations.
Public examples in this README stay repo-relative so shared guidance does not depend on a local machine path.

Important:

- the cached deploy/preview gate can become very fast after the first run
- that cache behavior does **not** mean the whole `full` regression will become a 20-second run

See [TEST_TIERS.md](TEST_TIERS.md) for the exact commands, usage rules, and runtime expectations.

## Runtime retention

Runtime outputs are intentionally treated as disposable local state:

- `artifacts/`
- `generated/`
- `diagnostics/screenshot/captures/`

Use the retention-safe cleanup command:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\cleanup-runtime-data.ps1"
```

See [RUNTIME_RETENTION_POLICY.md](RUNTIME_RETENTION_POLICY.md) for keep-count rules and cleanup behavior.

## Public API surface

The repo contains many internal scripts, but only a smaller set is intended as stable public surface.

See [PUBLIC_API_SURFACE.md](PUBLIC_API_SURFACE.md) for:

- human/operator entrypoints
- external client boundary entrypoints
- public docs and skills
- internal implementation vs test-only files

## P3 distribution readiness

P3 keeps the public surface clone-agnostic and repository-relative while preparing the repo for broader consumption.

Current public-safe distribution metadata:

- `package.json` advertises the MCP package name through `mcpName`
- `server.json` is the repo-root distribution metadata summary
- `MCP_CLIENT_USAGE.md` and `MCP_INSPECTOR_QUICKSTART.md` describe the repo-relative consumer path
- `MCP_REGISTRY_READINESS.md` documents the public-safe installer and registry readiness rules
- `wechat://installer-readiness` is the public, read-only hint for installer-facing registration guidance

This metadata is additive and does not change the stable validate/apply contract surface.

Next P3 step:

- installer-facing publish path and registry-readiness hints, still repo-relative and machine-neutral
- keep the local-vs-CI boundary explicit so GitHub-hosted checks stay public-safe while local DevTools checks remain required
- keep the recommended GitHub required checks limited to `ci-minimal / guardrails` and `ci-diagnostics / diagnostics-focused`; keep `fast` and `full` as local-only release-candidate validation

## Current baseline

- Layer 0 syntax check: pass (`211` scripts)
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
- use `TEST_TIERS.md` to choose the right tier instead of treating cached deploy-gate timing as full-regression timing.

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

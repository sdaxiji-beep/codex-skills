# Execution Checklist

Last updated: 2026-04-02 (P2 closure accepted; P3 active)

## Goal

Move this repo from a strong local workflow into a stable, shareable, and measurable WeChat Mini Program skill platform.

This checklist is ordered. Work should proceed from P0 to P2.

## P0 - Stabilize The Current System

These items improve trust, runtime hygiene, and release discipline. They come before major new capability work.

### P0.1 Minimal remote CI guardrail

Status: completed

Why:
- GitHub still needs visible checks instead of local-only proof.
- The first CI step should be stable and environment-safe.

Deliverables:
- add a minimal GitHub Actions workflow
- run repo-safe checks only:
  - guard-check
  - MCP boundary/doc sync checks
  - external client doc contract checks

Exit criteria:
- GitHub no longer shows `Checks (0)` for new pushes/PRs
- CI does not depend on local DevTools or automator

### P0.2 Test tier budget split

Status: completed

Why:
- current regression surface is healthy but the runtime budget is getting harder to reason about
- users are mixing cached deploy checks with full regression timing

Deliverables:
- define explicit test tiers:
  - L0 syntax/contracts
  - L1 diagnostics-focused
  - L2 fast-core
  - L3 full-integration
- publish target runtime budgets for each tier
- add one summary doc for "which command to run when"

Exit criteria:
- developers can choose the right test command without guesswork
- full regression timing is no longer confused with cached gate timing

### P0.3 Runtime artifact retention policy

Status: completed

Why:
- diagnostics screenshot captures and runtime artifacts can grow without bound
- release hygiene should not rely on manual cleanup

Deliverables:
- define retention policy for:
  - diagnostics screenshot captures
  - console logs
  - generated artifacts
- add cleanup script support for retention-safe pruning
- document release exclusions clearly

Exit criteria:
- runtime outputs are bounded
- release surface stays clean by default

### P0.4 Public API surface map

Status: completed

Why:
- the repo has many internal scripts; public entrypoints should be explicit
- shareability depends on a small stable public surface

Deliverables:
- classify entrypoints:
  - public
  - internal
  - test-only
- document the recommended public commands and boundary contracts

Exit criteria:
- external users can identify the correct entrypoints quickly
- internal implementation files are not mistaken for public API

## P1 - Strengthen The Automation Core

These items make the system smarter instead of merely broader.

### P1.1 Repair action expansion

Status: completed

Targets:
- wrong_page_path
- missing_required_element
- usingComponents path mismatch
- page not registered in app.json
- tab/page route mismatch
- selected runtime blocker mappings from console/compile evidence

Progress:
- first deterministic route/app registration batch completed:
  - wrong_page_path
  - missing_page_entry
  - tabbar_item_missing
- second deterministic component registration batch completed:
  - missing_required_element -> component dependency registration
  - component_not_rendered -> component dependency registration
- third deterministic gate-repair batch completed:
  - generation_gate_rejected -> usingComponents path correction
- fourth deterministic compile/runtime batch completed:
  - generation_gate_rejected -> WXML compile blocker normalization
- fifth deterministic data binding batch completed:
  - data_not_bound -> page data placeholder key insertion
- sixth deterministic runtime blocker batch completed:
  - error_page_visible -> route runtime blocker normalization
- seventh deterministic page-json contract batch completed:
  - generation_gate_rejected -> page JSON contract repair
  - supported repairs:
    - normalize `usingComponents` to `{}` when gate evidence says page `usingComponents` must be an object
    - remove invalid page-config keys when gate evidence explicitly names the forbidden key
- eighth deterministic page-config polish batch completed:
  - missing_navigation_bar -> page navigation title insertion
  - supported repair:
    - add `navigationBarTitleText` to the target page json when the page exists and the page json is valid
- ninth deterministic button-registration batch completed:
  - missing_required_button -> component dependency registration
  - supported repair:
    - when target resolves to a custom component tag, register `usingComponents.<tag> = "/components/<tag>/index"`
    - non-deterministic native-button cases remain blocked
- tenth deterministic validation-alias batch completed:
  - bundle_validation_failed -> deterministic gate/contract normalization
  - supported repair:
    - reuse existing `usingComponents` path correction
    - reuse page-json contract normalization
    - reuse WXML compile blocker normalization
  - unsupported bundle validation cases still block instead of guessing
- eleventh observability-facing batch completed:
  - metrics summary operator entrypoint delivered:
    - `scripts\get-diagnostics-metrics-summary.ps1`
    - `Get-DiagnosticsMetricsSummary`
  - command returns a stable human/operator digest over `latest-metrics-summary.json`
  - safe missing-file fallback contract verified
- validated by focused repair executor regression and diagnostics-focused suite
- next batch should target:
  - broader runtime blocker to repair-action mappings
  - selected higher-confidence runtime/data repairs beyond placeholder insertion

Exit criteria:
- repair loop can fix a broader set of common issues without user hand-holding

### P1.2 MCP-native structure

Status: completed

Why:
- current boundary is MCP-friendly, not fully MCP-native

Deliverables:
- design real MCP-facing tools/resources/prompts structure
- define resources such as:
  - project_state
  - latest_diagnostics_report
  - boundary_contract
- define prompts such as:
  - generate_page_bundle
  - repair_page_issue
  - patch_app_routes
- initial thin adapter delivered:
  - `scripts\wechat-mcp-server.mjs`
  - first tool-only MCP stdio surface wraps existing boundary without replacing it
- first fixed resources delivered:
  - `project_state`
  - `validation_plan`
  - `latest_diagnostics_metrics`
  - `boundary_contract`
- second fixed-resource expansion delivered:
  - `external_client_entrypoints`
  - `release_package`
- first prompt set delivered:
  - `generate_page_bundle`
  - `generate_component_bundle`
  - `repair_page_issue`
  - `patch_app_routes`
- minimal MCP surface verification expanded:
  - narrow server smoke/contract coverage now includes prompt/resource presence checks

Exit criteria:
- the repo can be consumed more naturally by MCP-capable clients

### P1.3 Metrics and observability

Status: completed

Targets:
- automator success rate
- screenshot fallback rate
- compile blocker hit rate
- average repair rounds
- repair success rate
- top issue families

Progress:
- passive metrics artifact writer delivered:
  - `diagnostics\Write-DiagnosticsMetrics.ps1`
- first instrumentation added:
  - `diagnostics\Invoke-DetectorRound.ps1`
  - `diagnostics\Invoke-RepairLoopAuto.ps1`
- metrics artifact path:
  - `artifacts\wechat-devtools\diagnostics\latest-metrics.json`
- aggregate summary artifact delivered:
  - `artifacts\wechat-devtools\diagnostics\latest-metrics-summary.json`
- focused metrics contract test added:
  - `diagnostics\Test-DiagnosticsMetricsWriter.ps1`
- quickcheck metrics aggregation delivered:
  - wall-clock duration totals and average
  - quickcheck family counts
  - quickcheck per-test counts
- summary fallback coverage delivered:
  - unreadable or missing `latest-metrics-summary.json` is rebuilt by the writer and verified by test
- metrics summary readability contract delivered:
  - `diagnostics\METRICS_SUMMARY.md`
  - `diagnostics\Test-MetricsSummaryDoc.ps1`
- operator digest entrypoint delivered:
  - `scripts\get-diagnostics-metrics-summary.ps1`
  - `scripts\test-diagnostics-metrics-summary-command.ps1`

Exit criteria:
- improvement work can be measured, not guessed

## P2 - Platform Standardization

These items hardened the public surface after P0/P1 became stable.

### P2.1 Public-safe MCP/consumer standardization

Status: completed

Deliverables:
- additive MCP tools/resources/prompts surface
- inspector/client read-first guidance
- clone-agnostic public docs and surface maps

### P2.2 Public-safe metrics/operator standardization

Status: completed

Deliverables:
- additive summary/digest/trend/operator views
- public-safe, machine-neutral operator wording
- stable operator guidance without private path assumptions

### P2.3 CI/governance public polish

Status: completed

Deliverables:
- repo-relative CI/local validation matrix
- recommended required checks guidance
- release/public docs aligned with clone-agnostic sharing

## P3 - Distribution And Operational Hardening

These items begin after P2 closure and should preserve the now-stable public-safe contracts.

### P3.1 Distribution readiness

Status: active

Deliverables:
- installer-facing usage path
- registry/MCP packaging readiness
- public publish metadata that stays repo-relative and machine-neutral
- installer-facing companion guidance that names the repo-relative registry-readiness rules
- distribution metadata skeleton already in place:
  - `package.json` advertises `mcpName`
  - `server.json` summarizes the repo-root MCP distribution surface
  - `scripts\\test-wechat-mcp-distribution-metadata.ps1` verifies the additive metadata contract
  - `scripts\\test-wechat-mcp-registry-readiness.ps1` verifies the public-safe registry readiness guide
  - `MCP_CLIENT_USAGE.md` and `MCP_INSPECTOR_QUICKSTART.md` point to the repo-relative consumer path
- next P3.1 step:
  - installer-facing publish path and registry-readiness hints without changing validate/apply contracts

### P3.2 Operational hardening

Status: active

Deliverables:
- keep full acceptance stable under the documented sequential execution model
- reduce remaining validation hotspots only when the contract stays unchanged
- preserve mainline health while new distribution-facing assets are added
- keep `fast` reserved for routine developer confidence, not heavy cache-proof drills
- treat expensive cache-stability probes as focused/manual or `full`-only unless their runtime stays negligible

### P3.3 Selective cross-platform reduction

Status: pending

Deliverables:
- reduce hard PowerShell coupling only where it improves distribution or consumer adoption
- evaluate boundary-first Node orchestration paths without breaking stable local Windows workflows

## Execution Order

1. P0.1 Minimal remote CI guardrail
2. P0.2 Test tier budget split
3. P0.3 Runtime artifact retention policy
4. P0.4 Public API surface map
5. P1.1 Repair action expansion
6. P1.2 MCP-native structure
7. P1.3 Metrics and observability
8. P2 platform standardization
9. P3 distribution and operational hardening

## Current step

Current step: P3.1 Distribution readiness, with P3.2 operational hardening continuing in parallel

## Regression discipline

- `GuardCheckOnly` is the minimum syntax/guard surface gate.
- `diagnostics-focused` is the default targeted acceptance gate after diagnostics or repair changes.
- `fast` is the routine sequential acceptance gate and must stay low-cost enough for regular local use.
- `full` is the stage/release acceptance gate and is the correct home for heavier operational hardening probes.
- shared-artifact acceptance must be validated sequentially, not in parallel.

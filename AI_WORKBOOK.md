# AI Workbook

Last updated: 2026-04-05

## Purpose

This workbook defines how an AI client should operate this repo when the task is:

- natural-language WeChat mini program generation
- structured bundle validation/apply
- acceptance-driven repair
- registry-backed component/page assembly

This is an internal operating guide.

It does not replace the stable public boundary contract.

## Standard Workflow

When an AI receives a generated/local WeChat task, it should follow this order:

1. Read the TaskSpec schema:
   - `schemas\wechat-task-spec.schema.json`
2. Translate the request into a TaskSpec JSON object.
3. Compile the TaskSpec into bundle payloads:
   - `page_bundle`
   - `component_bundle`
   - `app_patch`
4. Prefer registry-backed assets during compilation:
   - `assets\registry.json`
   - `schemas\wechat-asset-registry.schema.json`
5. Run boundary validation first:
   - `validate_component_bundle`
   - `validate_page_bundle`
   - `validate_app_json_patch`
6. Only after validation passes, run:
   - `apply_component_bundle`
   - `apply_page_bundle`
   - `apply_app_json_patch`
7. Run acceptance checks:
   - `scripts\wechat-acceptance-checks.ps1`
8. If acceptance fails, enter the repair path:
   - `scripts\wechat-acceptance-repair-loop.ps1`
9. Re-run validation/apply/acceptance until:
   - success
   - repair exhausted
   - blocked environment/runtime condition

## Operational Rule

Preferred execution shape:

- Natural Language
- `TaskSpec`
- translator
- compiler
- registry-backed page/component lookup
- boundary validate/apply
- acceptance checks
- acceptance-driven repair

Do **not** default to direct file editing when the task can be expressed through the structured TaskSpec pipeline.

## Registry-first Rule

Asset-backed generation is now the preferred path for stable families.

Use the registry-backed compiler flow first:

- `assets\registry.json`
- `schemas\wechat-asset-registry.schema.json`
- `scripts\wechat-asset-registry-validator.ps1`

Current stable registry-backed assets:

- components
  - `cta-button`
  - `product-card`
  - `buy-button`
  - `food-item`
  - `cart-summary`
- page templates
  - `coupon-empty-state`
  - `product-listing`
  - `product-detail`
  - `food-order`
  - `food-checkout`

Operational guidance:

- prefer registry-backed component/page templates over legacy hardcoded fallback
- treat fallback as compatibility-only during transition
- if a task family is registry-backed, do not reintroduce inline template drift in the compiler
- run the registry validator before parity-sensitive migration work
- for multi-page flows, compile and execute each page root through the same boundary contract instead of bypassing validation
- current registry-backed cross-page example:
  - `food-order-flow`
  - listing page -> checkout page navigator
  - app patch registers both routes before acceptance

## Required Files and Entrypoints

Primary files:

- `schemas\wechat-task-spec.schema.json`
- `schemas\wechat-page-bundle.schema.json`
- `schemas\wechat-component-bundle.schema.json`
- `schemas\wechat-asset-registry.schema.json`
- `scripts\wechat-task-spec.ps1`
- `scripts\wechat-task-translator.ps1`
- `scripts\wechat-task-bundle-compiler.ps1`
- `scripts\wechat-task-executor.ps1`
- `scripts\wechat-acceptance-checks.ps1`
- `scripts\wechat-acceptance-repair-loop.ps1`
- `scripts\wechat-asset-registry-validator.ps1`
- `scripts\wechat-mcp-tool-boundary.ps1`

Primary PowerShell entrypoint:

- `scripts\wechat.ps1`

## Error Handling

### 1. Boundary `status=error`

Meaning:

- input contract failure
- malformed payload
- missing required fields

Action:

- fix TaskSpec or compiled bundle payload first
- do not continue to apply

### 2. `gate_status=retryable_fail`

Meaning:

- payload is structurally close, but validation or apply needs correction

Action:

- revise the generated bundle
- retry validation/apply
- continue through the repair path when possible

### 3. `gate_status=hard_fail`

Meaning:

- invalid or unsafe request
- do not keep retrying blindly

Action:

- stop automatic retries
- escalate with a clear reason

### 4. `repair_exhausted`

Meaning:

- the acceptance-driven repair loop hit its retry budget

Action:

- return a structured failure report
- include missed checks and latest repair history
- do not silently report success

### 5. AST Gate / compile errors

Examples:

- WXML compile errors
- invalid Mini Program JS constructs
- malformed generated bundle content

Action:

- treat as real blockers
- convert them into repair work or explicit failure
- do not bypass the boundary by writing files directly just to "make it pass"

## Safety Rules

- Never modify the configured business project path directly
- Keep generated task work inside:
  - `generated\`
  - `sandbox\`
- Do not change the core contract in:
  - `scripts\wechat-mcp-tool-boundary.ps1`
- Do not silently ignore preview/upload restrictions for `touristappid`

## Real Drill Rule

For local real drills:

- prefer `Open=$true`
- use `Preview=$false` unless preview is explicitly required
- when preview fails because of `touristappid`, treat that as an expected guarded limitation, not as a false "system success"

## Agent Role

For this repo, AI should behave as:

- translator
- compiler coordinator
- validation/apply orchestrator
- repair-loop operator

It should not behave as an unconstrained file generator by default.

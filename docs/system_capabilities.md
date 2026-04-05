# System Capabilities

Last updated: 2026-04-05
Milestone: `v2.1.0-rc.1`

## What the system can do

### Natural-language to Mini Program pipeline

Supported internal workflow:

1. Natural-language prompt
2. `TaskSpec`
3. translator
4. bundle compiler
5. registry-first asset lookup
6. boundary validate/apply
7. acceptance checks
8. acceptance-driven repair
9. generated project open / preview-safe path

Main entrypoints:

- `scripts\wechat.ps1`
- `scripts\wechat-mcp-pipeline-bridge.ps1`
- `scripts\wechat-mcp-server.mjs` (`run_task_pipeline`)

### Supported task families

- marketing empty-state
  - `coupon-empty-state`
  - `activity-not-started`
  - `benefits-empty-state`
- product
  - `product-listing`
  - `product-detail`
- food ordering
  - `food-order`
  - `food-order-flow`

### Registry-backed assets

Components:

- `cta-button`
- `product-card`
- `buy-button`
- `food-item`
- `cart-summary`

Page templates:

- `coupon-empty-state`
- `product-listing`
- `product-detail`
- `food-order`
- `food-checkout`

### Validation and repair

The system currently supports:

- boundary contract validation for page/component/app payloads
- AST-style gate protection through the existing boundary/generation stack
- acceptance checks for task semantics
- acceptance-driven repair loop for supported missing elements
- registry validator and parity checks for migrated assets

### Cross-page routing

The system now supports:

- multi-page `TaskSpec` targets
- app route registration for more than one generated page
- navigator-based link verification
- cross-page generated drill coverage for:
  - `food-order-flow`

## How to call it

### Local PowerShell

```powershell
. .\scripts\wechat.ps1
Invoke-WechatTask -Prompt "build a product listing mini program"
```

### Internal bridge

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-pipeline-bridge.ps1 -Prompt "build a food order flow with a listing page and a checkout page linked together." -Open $false
```

### MCP

Use the repo-root MCP server tool:

- `run_task_pipeline`

Inputs:

- `prompt`
- `open`

## What is intentionally not supported yet

- arbitrary unconstrained app generation from any prompt
- real production deploy without guard/confirmation
- direct write access to `D:\卤味`
- automatic upload/deploy from `touristappid`
- public MCP exposure of all internal translator/compiler/repair internals
- full registry migration for every historical family/page in the repo

## Operational status

Current status:

- maintenance-first
- registry-first generation stable
- fallback code intentionally preserved
- release candidate marker:
  - `v2.1.0-rc.1`

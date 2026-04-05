# Golden Path

Last updated: 2026-03-24

## Purpose

This document defines the Phase 1 end-to-end golden path for the controlled generation workflow.

The goal is to prove one complete and understandable route from a natural-language request to a guarded WeChat Mini Program project result.

This is the target product path:

1. natural-language request
2. component generation
3. page generation
4. page uses the component
5. append-only app.json route patch
6. preview guard
7. upload/deploy guard

## Scope

This golden path is not the "fastest possible path".
It is the clearest path that demonstrates the core design:

- generation is separated from write
- write is separated from validation
- route changes are append-only
- preview/upload are guarded

## Preconditions

Before running the full path, the workspace must expose the following entrypoints:

- `Invoke-WechatCreate`
- `Invoke-WechatGenerateComponent`
- `Invoke-WechatGeneratePage`
- `Invoke-WechatPatchAppJson`
- `Invoke-GeneratedProjectPreview`
- `Invoke-GeneratedProjectDeployGuard`

If the current workspace does not yet expose the page/component/app-patch entrypoints, this document still serves as the product contract for Phase 1. The missing entrypoints must be integrated before the golden path can be fully executed in this workspace.

## Golden Path Scenario

Use one simple but complete scenario:

- component: `components/cta-button/index`
- page: `pages/about/index`
- route patch: `pages/about/index`

Natural-language intent:

`Create an about page for a mini program. The page should use one reusable CTA button component and then register the page safely in app.json.`

## Step 1 - Create A Project Shell

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")

Invoke-WechatBootstrap
Invoke-WechatDoctor
Invoke-WechatCreate `
  -Prompt "build a notebook mini program" `
  -Open $false `
  -Preview $false
```

Expected outcome:

- project is created under `generated/`
- no preview is assumed
- generated project still uses preview-first policy

## Step 2 - Generate One Reusable Component

```powershell
Invoke-WechatGenerateComponent `
  -Prompt "Create a reusable CTA button component with a text label property" `
  -ComponentPath "components/cta-button/index"
```

Expected outcome:

- component bundle is produced
- component passes component gate
- files are written only after validation

## Step 3 - Generate One Page That Uses The Component

```powershell
Invoke-WechatGeneratePage `
  -Prompt "Create an about page with an app logo, version text, and one CTA button using the existing cta-button component" `
  -PagePath "pages/about/index"
```

Expected outcome:

- page bundle is produced
- page references the known component through `usingComponents`
- page passes page gate before write

## Step 4 - Register The Route Through Append-Only Patch

```powershell
Invoke-WechatPatchAppJson `
  -Prompt "Register the about page in app.json routes" `
  -PagePaths "pages/about/index"
```

Expected outcome:

- only `append_pages` patch shape is used
- route is added only if the physical page exists
- no full overwrite of `app.json`

## Step 5 - Preview Guard

```powershell
Invoke-GeneratedProjectPreview -RequireConfirm $false
```

Expected outcome:

- preview command executes against the generated project
- success or failure is reported truthfully
- no upload/deploy happens in this step

## Step 6 - Upload/Deploy Guard

```powershell
Invoke-GeneratedProjectDeployGuard
```

Expected outcome:

- `touristappid` returns `denied`
- a real appid project can become `eligible`
- no upload is attempted unless explicit follow-up action is requested

## Acceptance Criteria

The golden path is considered complete when all of the following are true:

1. one documented scenario covers component -> page -> app.json patch -> preview guard
2. every step maps to a named script entrypoint
3. the route registration step is append-only, never full-file overwrite
4. preview and deploy are separated
5. the same path can be explained to a new user without repo-internal assumptions

## Contract Verification

Use the focused contract check:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-golden-path-contract.ps1
```

Expected contract result states:

- `status = ready` means all required docs and entrypoints are available.
- `status = blocked` means docs exist but one or more required entrypoints are still missing in the current workspace integration.

Run the focused execution drill:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-golden-path-drill.ps1
```

Expected drill result:

- test name is `golden-path-drill`
- `pass = true`
- `guard_status` is a valid deploy-guard result (`denied` or `eligible`)

## Non-Goals

This golden path does not yet promise:

- cross-platform execution
- AST-grade validation
- generic MCP-client portability
- one-sentence fully autonomous execution in every client

Those belong to later phases in `PHASE_PLAN.md`.

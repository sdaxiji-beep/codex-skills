# CLAUDE.md

This repo supports Claude-style agent execution with explicit state-first workflow.

## Mandatory startup

1. Read `PROJECT_STATE.md` first.
2. Start from `## Current blocker`.
3. Do not repeat anything listed in `## Completed in this round`.
4. Update `PROJECT_STATE.md` after each completed task.

## Safety constraints

- Never modify the user business-code workspace.
- Use preview-first behavior for generated projects.
- Keep `touristappid` blocked for upload/deploy.

## Entrypoint map

Load commands:

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")
```

Core user flows:

- `Invoke-WechatCreate`
- `Invoke-WechatGenerateComponent`
- `Invoke-WechatGeneratePage`
- `Invoke-WechatPatchAppJson`
- `Invoke-GeneratedProjectPreview`
- `Invoke-GeneratedProjectDeployGuard`

Internal task-automation flows:

- `Invoke-WechatTaskTranslator`
- `Invoke-TaskSpecToBundle`
- `Invoke-WechatTaskExecution`
- `Invoke-AcceptanceChecks`
- `Invoke-AcceptanceRepairLoop`

MCP-style tool boundary entry:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-tool-boundary.ps1 -Operation describe_execution_profile
```

Supported operations:

- `describe_contract`
- `describe_execution_profile`
- `validate_page_bundle`
- `apply_page_bundle`
- `validate_component_bundle`
- `apply_component_bundle`
- `validate_app_json_patch`
- `apply_app_json_patch`

Client execution guidance:

- auto-retry only when apply result is `gate_status=retryable_fail` (`exit_code=1`)
- stop and escalate when `gate_status=hard_fail` (`exit_code=2`)
- treat boundary `status=error` as input-contract failure and fix payload first

Task execution guidance:

- prefer the `TaskSpec` pipeline over direct file edits whenever the request can be expressed as a generated/local task workflow
- expected order:
  - translator
  - compiler
  - executor
  - acceptance checks
  - acceptance repair loop
- do not bypass the translator/compiler/executor path just to write page/component files directly unless the structured path cannot represent the task

## Validation layers

- L0: `test-wechat-skill.ps1 -GuardCheckOnly`
- L1: `test-diagnostics-focused.ps1`
- L2: `test-wechat-skill.ps1 -SkipSmoke -Tag fast`
- L3: `test-wechat-skill.ps1 -Tag full`

Use `TEST_TIERS.md` as the source of truth for tier intent, sequencing rules, and runtime expectations.

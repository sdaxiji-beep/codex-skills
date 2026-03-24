# CLAUDE.md

This repo supports Claude-style agent execution with explicit state-first workflow.

## Mandatory startup

1. Read `PROJECT_STATE.md` first.
2. Start from `## Current blocker`.
3. Do not repeat anything listed in `## Completed in this round`.
4. Update `PROJECT_STATE.md` after each completed task.

## Safety constraints

- Never modify the user business-code workspace (`D:\卤味` in this setup).
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

## Validation layers

- Layer 0: syntax check
- Layer 1: focused tests
- Layer 2: `test-p2-fast.ps1`
- Layer 3: `test-p2-mini.ps1`
- Layer 4: `test-wechat-skill.ps1 -SkipSmoke`
- Layer 5: `wechat-run.ps1` with human confirmation

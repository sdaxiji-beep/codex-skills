# External Client Entrypoints

This document defines minimal entrypoints for Claude/Cursor/Gemini-style clients that call local scripts in this repo.

## Preconditions

```powershell
$RepoRoot = (Get-Location).Path
Set-Location $RepoRoot
```

## Boundary contract discovery

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-tool-boundary.ps1 -Operation describe_contract
powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-tool-boundary.ps1 -Operation describe_execution_profile
```

## Payload contract reminders

- Page bundle JSON must include top-level `page_name` and `files`.
- Component bundle JSON must include top-level `component_name` and `files`.
- App patch JSON must include top-level `append_pages`.
- Preview/write confirmation payloads should use generic scope values such as `current-project`, not rooted machine-specific paths.

## Validation entrypoints

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-tool-boundary.ps1 `
  -Operation validate_page_bundle `
  -JsonFilePath ".\.agents\tasks\bundle_page_home.json" `
  -TargetWorkspace (Get-Location).Path

powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-tool-boundary.ps1 `
  -Operation validate_component_bundle `
  -JsonFilePath ".\.agents\tasks\bundle_component_card.json" `
  -TargetWorkspace (Get-Location).Path

powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-tool-boundary.ps1 `
  -Operation validate_app_json_patch `
  -JsonFilePath ".\.agents\tasks\app_json_patch.json" `
  -TargetWorkspace (Get-Location).Path
```

## Apply entrypoints

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-tool-boundary.ps1 `
  -Operation apply_page_bundle `
  -JsonFilePath ".\.agents\tasks\bundle_page_home.json" `
  -TargetWorkspace (Get-Location).Path

powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-tool-boundary.ps1 `
  -Operation apply_component_bundle `
  -JsonFilePath ".\.agents\tasks\bundle_component_card.json" `
  -TargetWorkspace (Get-Location).Path

powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-tool-boundary.ps1 `
  -Operation apply_app_json_patch `
  -JsonFilePath ".\.agents\tasks\app_json_patch.json" `
  -TargetWorkspace (Get-Location).Path
```

## Client behavior contract

- Retry automatically only when apply result has `gate_status=retryable_fail` (`exit_code=1`).
- Stop and escalate to user when apply result has `gate_status=hard_fail` (`exit_code=2`).
- Fix payload contract first when boundary `status=error`.

## Non-goals

- This entrypoint map does not bypass release guard rules.
- This entrypoint map does not allow writes outside validated page/component/app.json patch scopes.

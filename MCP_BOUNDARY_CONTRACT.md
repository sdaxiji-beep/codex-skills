# MCP Boundary Contract

Interface version: `mcp_tool_boundary_v1`

Entrypoint:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\wechat-mcp-tool-boundary.ps1 -Operation <op> [-JsonPayload "<json>" | -JsonFilePath "<path>"] [-TargetWorkspace "<path>"]
```

## Operations

- `describe_contract`
- `describe_execution_profile`
- `validate_page_bundle`
- `apply_page_bundle`
- `validate_component_bundle`
- `apply_component_bundle`
- `validate_app_json_patch`
- `apply_app_json_patch`

## Response envelope

All operations return JSON with:

- `status`: `success | failed | error`
- `operation`: operation name
- `interface_version`: `mcp_tool_boundary_v1`

Validation operations add:

- `gate_status`: `pass | retryable_fail | hard_fail`
- `errors`: string array

Profile operation (`describe_execution_profile`) adds:

- `platform`: current runtime/platform contract
- `execution_profile`: validate/apply operation groups and exit-code mapping
- `client_guidance`: retry/abort/fallback guidance for external clients

Apply operations add:

- `exit_code`: child apply script exit code
- `gate_status`: mapped from exit code
  - `0 -> pass`
  - `1 -> retryable_fail`
  - `2 -> hard_fail`
  - other -> `unknown`
- `stdout`
- `stderr`

## Input contract

- For non-describe operations (`describe_contract` / `describe_execution_profile` do not require payload), one of:
  - `-JsonPayload`
  - `-JsonFilePath`
- Bundle payload requirements:
  - page bundle: top-level `page_name` plus `files[]`
  - component bundle: top-level `component_name` plus `files[]`
  - app patch: top-level `append_pages`
- If both are missing:
  - process exit code is `1`
  - response `status=error`
  - response includes contract message: `JsonPayload or JsonFilePath is required.`

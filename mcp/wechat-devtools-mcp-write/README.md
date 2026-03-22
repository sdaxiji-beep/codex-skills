# wechat-devtools-mcp-write (guarded scaffold)

Guarded MCP server scaffold for future write and deploy operations.

## Status

- Separate from readonly MCP v1
- Disabled by default
- Not registered in `.agent/mcps.json`
- Starts only when policy and environment both allow it
- No tools are exposed yet

## Activation Rules

- `policy.json` is the source of truth for enablement.
- Current policy keeps `enabled=false`.
- Even if policy is changed later, startup still requires `WECHAT_WRITE_MCP_ENABLE=1`.
- Startup is blocked while `allow_tools_before_policy_review=false`.

## Planned First-Wave Tools

- `preview_project` -> `Invoke-WechatPreview`
- `deploy_cloud_function` -> `Invoke-DeployCloudFunction`
- `deploy_changed_cloud_functions` -> `Invoke-DeployChangedCloudFunctions`
- `safe_write_file` -> `Invoke-SafeWrite`

These are whitelist candidates only. None of them are exposed yet.

## Client Confirmation Contract

The write MCP policy now defines a client confirmation callback contract:

- contract version: `write_confirm_v1`
- callback type: `client_confirmation`
- required fields:
  - `request_id`
  - `action`
  - `scope`
  - `summary`
  - `risk_level`
  - `requires_explicit_yes`
  - `expires_in_seconds`

`preview_project` already returns this contract and a sample confirmation request payload, but still returns `blocked_by_policy`.

## Tool-Level Gate

`preview_project` also requires a tool-level environment gate:

- `WECHAT_WRITE_TOOL_PREVIEW_ENABLE=1`

Without this gate, the tool returns `blocked_by_tool_flag` and does not execute any deploy action.

## Gate Probe

Use the readonly gate probe script to see exactly which gate is currently blocking startup/tool execution:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\mcp-write-gate-status.ps1 -AsJson
```

For a 4-case dry-run matrix (none/service_only/tool_only/both_envs):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\mcp-write-gate-dryrun.ps1 -AsJson
```

Latest matrix artifact:

- `<repo-root>\artifacts\mcp-write-gate-dryrun-latest.json`

Readiness summary (single command):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\mcp-write-readiness.ps1 -AsJson
```

Latest readiness artifact:

- `<repo-root>\artifacts\mcp-write-readiness-latest.json`

## Intent

This server is reserved for future guarded operations such as:

- controlled file writes
- preview and upload commands
- cloud function deploy commands

Those operations remain in PowerShell scripts for now and are not exposed through MCP yet.

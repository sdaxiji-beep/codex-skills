# wechat-devtools-mcp-write Enable Checklist (Stage 3 Gate)

This checklist is for controlled transition from readonly-only operations to guarded write/deploy MCP exposure.

## Default Position

- Server remains disabled by policy.
- No write/deploy tool is considered active by default.
- Approval gates must pass before any enablement attempt.

## Mandatory Preconditions

1. Readonly baseline is stable.
   - `Invoke-WechatReadonlyCheck -AsJson` reports `stable=true`.
2. Policy file exists and is valid.
   - `mcp\wechat-devtools-mcp-write\policy.json`.
3. Gate status is explicitly blocked before release.
   - `scripts\mcp-write-gate-status.ps1 -AsJson`.
4. Readiness output is tracked.
   - `scripts\mcp-write-readiness.ps1 -AsJson`.

## First Tool Rollout Order

1. `preview_project`
2. `deploy_cloud_function`
3. `deploy_changed_cloud_functions`
4. `safe_write_file`

Do not skip order. Do not parallel-enable multiple tools.

## Go/No-Go Rules

- GO only when all required policy/review/env gates pass.
- NO-GO on any missing gate.
- Any NO-GO keeps server/tool disabled and records blocked reason.

## Validation Before Any Enable Action

```powershell
powershell -ExecutionPolicy Bypass -File G:\codex专属\scripts\mcp-write-gate-status.ps1 -AsJson
powershell -ExecutionPolicy Bypass -File G:\codex专属\scripts\mcp-write-gate-dryrun.ps1 -AsJson
powershell -ExecutionPolicy Bypass -File G:\codex专属\scripts\mcp-write-readiness.ps1 -AsJson
```

## Safety Boundary

- This checklist does not authorize deploy/write by itself.
- Client confirmation contract (`write_confirm_v1`) remains required.

# wechat-devtools-mcp Operations (Readonly v1)

## Scope

This server is readonly-only in v1.

- Allowed: page read, data read, validation, cloud-function listing, project-state read.
- Not allowed: write, deploy, upload, cloud mutation.

## Start

```powershell
cd <repo-root>\mcp\wechat-devtools-mcp
npm run start
```

## Required Environment

- WeChat DevTools is installed and logged in.
- Workspace scripts exist under `<repo-root>\scripts`.
- Local MCP registration points to this server:
  - `<repo-root>\.agent\mcps.json`

## Health Checks

1. Server type check

```powershell
node -e "const fs=require('fs');const p='G:/codex专属/.agent/mcps.json';const j=JSON.parse(fs.readFileSync(p,'utf8'));console.log(Object.keys(j.mcpServers||{}))"
```

2. Readonly check (status + history + trend)

```powershell
powershell -ExecutionPolicy Bypass -Command ". .\scripts\wechat.ps1; Invoke-WechatReadonlyCheck -AsJson"
```

3. Full regression (optional)

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\test-wechat-skill.ps1 -SkipSmoke
```

## Expected Outputs

- `Invoke-WechatReadonlyCheck -AsJson` returns JSON with:
  - `stable=true`
  - `health.pass=true`
  - `status.pass=true`
  - `trend.pass=true`

## Failure Triage

1. If `get_current_page` fails:
- Confirm DevTools project session is active.
- Confirm detected service port is reachable.

2. If `list_cloud_functions` fails:
- Confirm project and cloud environment are available.
- Run deploy guard test to validate toolchain context.

3. If trend/status check fails:
- Inspect artifacts:
  - `<repo-root>\artifacts\mcp-readonly-health-latest.json`
  - `<repo-root>\artifacts\mcp-readonly-status-latest.json`
  - `<repo-root>\artifacts\mcp-readonly-status-history.jsonl`

## Change Policy

Before v2 write/deploy enablement:

- Keep this server readonly-only.
- Any write/deploy exposure must stay in the isolated write MCP server with policy gates.

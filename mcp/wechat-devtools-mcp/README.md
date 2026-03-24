# wechat-devtools-mcp (readonly v1)

Readonly MCP server for the `G:\codex专属` WeChat automation workspace.

## Tools

- `get_current_page`
- `get_page_data`
- `run_validation`
- `list_cloud_functions`
- `get_project_state`

All tools are readonly in v1. Write and deploy tools are intentionally excluded.

## Run

```powershell
cd G:\codex专属\mcp\wechat-devtools-mcp
npm run start
```

## Local Registration

The local registration lives in:

- `G:\codex专属\.agent\mcps.json`

This readonly server is the only MCP server currently wired into the local MCP config for the WeChat workflow.

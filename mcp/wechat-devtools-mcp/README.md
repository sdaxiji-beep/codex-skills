# wechat-devtools-mcp (readonly v1)

Readonly MCP server for the local WeChat automation workspace at `<repo-root>`.

## Tools

- `get_current_page`
- `get_page_data`
- `run_validation`
- `list_cloud_functions`
- `get_project_state`

All tools are readonly in v1. Write and deploy tools are intentionally excluded.

## Run

```powershell
cd <repo-root>\mcp\wechat-devtools-mcp
npm run start
```

## Local Registration

The local registration lives in:

- `<repo-root>\.agent\mcps.json`

This readonly server is the only MCP server currently wired into the local MCP config for the WeChat workflow.

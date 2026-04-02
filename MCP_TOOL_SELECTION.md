# MCP Tool Selection Guide

## Purpose
Use this guide to choose the smallest safe MCP surface for a task.

## Common Tasks
- Inspect current exposure: `server_inventory`
- Read the public entrypoints: `external_client_entrypoints`
- Read the boundary contract: `boundary_contract`
- Check the current release scope: `release_package`
- Draft a page bundle: `generate_page_bundle`
- Draft a component bundle: `generate_component_bundle`
- Draft an app.json route patch: `patch_app_routes`
- Validate a page bundle: `validate_page_bundle`
- Validate a component bundle: `validate_component_bundle`
- Validate an app.json patch: `validate_app_json_patch`
- Repair a detected page issue: `repair_page_issue`

## Selection Rules
1. Read `server_inventory` first when you need the current live surface.
2. Prefer draft prompts before direct writes.
3. Validate before apply.
4. Use `tool_selection_guide` when you need a quick routing hint for the right tool.
5. Keep write payloads repo-relative where possible.

## Notes
- The PowerShell boundary remains the execution kernel.
- This guide is read-only and meant for inspector clients.

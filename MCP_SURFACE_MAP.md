# MCP Surface Map

## Purpose
Use this to move from a public MCP surface name to the smallest matching doc or test.
The map is intentionally read-only and avoids machine-local assumptions.

## Read First
- `wechat://server-inventory`
- `wechat://read-order`
- `wechat://consumer-router`
- `wechat://path-conventions`
- `wechat://prompt-selection-guide`
- `wechat://task-map`
- `wechat://surface-map`
- `wechat://inspector-quickstart`
- `wechat://tool-selection-guide`
- `wechat://client-usage-guide`
- `wechat://boundary-contract`

## Surface -> Doc / Test
- `describe_contract` -> `MCP_BOUNDARY_CONTRACT.md`
- `describe_execution_profile` -> `RELEASE_PACKAGE.md`
- `validate_page_bundle` -> `GOLDEN_PATH.md` and `scripts\test-wechat-mcp-tool-boundary-contract.ps1`
- `apply_page_bundle` -> `GOLDEN_PATH.md` and `scripts\test-wechat-mcp-tool-boundary-contract.ps1`
- `validate_component_bundle` -> `PUBLIC_API_SURFACE.md` and `scripts\test-wechat-mcp-tool-boundary-contract.ps1`
- `apply_component_bundle` -> `PUBLIC_API_SURFACE.md` and `scripts\test-wechat-mcp-tool-boundary-contract.ps1`
- `validate_app_json_patch` -> `MCP_BOUNDARY_CONTRACT.md` and `scripts\test-wechat-mcp-tool-boundary-file-input-contract.ps1`
- `apply_app_json_patch` -> `MCP_BOUNDARY_CONTRACT.md` and `scripts\test-wechat-mcp-tool-boundary-file-input-contract.ps1`
- `generate_page_bundle` -> `GOLDEN_PATH.md`
- `generate_component_bundle` -> `PUBLIC_API_SURFACE.md`
- `repair_page_issue` -> `diagnostics\DETECTOR_BRIDGE_CONTRACT.md` and `diagnostics\Invoke-RepairLoopAuto.ps1`
- `patch_app_routes` -> `diagnostics\DETECTOR_BRIDGE_CONTRACT.md` and `scripts\test-generation-gate-app-json-v1.ps1`
- `consumer_router` -> repo-relative first-hop guidance for consumer clients
- `path_conventions` -> repo-relative path guidance for inspector and consumer clients

## Resource -> Use
- `wechat://server-inventory` -> live surface confirmation
- `wechat://read-order` -> recommended first-pass inspection sequence
- `wechat://consumer-router` -> deterministic first-hop guidance for consumer clients
- `wechat://path-conventions` -> clone-agnostic repo-relative path guidance
- `wechat://prompt-selection-guide` -> clone-agnostic prompt selection guidance
- `wechat://task-map` -> compact task-to-resource discovery hints
- `wechat://inspector-quickstart` -> shortest read-first inspector path
- `wechat://tool-selection-guide` -> safest tool choice when the task is ambiguous
- `wechat://client-usage-guide` -> generic client flow before validate/apply
- `wechat://prompt-selection-guide` -> choose the smallest safe prompt before drafting
- `wechat://boundary-contract` -> stable boundary contract details
- `wechat://validation-plan` -> validation tier guidance
- `wechat://installer-readiness` -> `MCP_REGISTRY_READINESS.md`
- `wechat://registry-readiness` -> `MCP_REGISTRY_READINESS.md`
- `wechat://distribution-quickstart` -> `MCP_DISTRIBUTION_QUICKSTART.md`
- `wechat://registration-guidance` -> `MCP_REGISTRATION_GUIDANCE.md`

## Notes
- This map is read-only.
- Use `server_inventory` first when you need the current live surface.
- Use `tool_selection_guide` when you need the narrowest safe tool for a task.

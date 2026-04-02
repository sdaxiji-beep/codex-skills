# MCP Client Usage Guide

## Purpose
Use this repo through the MCP server as a thin adapter over the existing PowerShell boundary.

## Portable Notes
- This surface is client-agnostic and should work from any checkout of the repo.
- Do not hardcode machine-local paths in prompts or examples; keep payloads repo-relative when possible.
- Prefer read-only resources before any write tool call.
- The repo root `server.json` is the public-safe distribution metadata summary for this MCP surface.
- `MCP_REGISTRY_READINESS.md` is the public-safe checklist for future registry or installer publication work.
- `MCP_DISTRIBUTION_QUICKSTART.md` is the shortest public-safe first hop for installer-facing or consumer-facing distribution work.
- `MCP_REGISTRATION_GUIDANCE.md` is the clone-agnostic registration guide for client setup.

## Read First
- `wechat://server-inventory`
- `wechat://read-order`
- `wechat://consumer-router`
- `wechat://path-conventions`
- `wechat://prompt-selection-guide`
- `wechat://task-map`
- `wechat://inspector-quickstart`
- `wechat://surface-map`
- `wechat://tool-selection-guide`
- `wechat://boundary-contract`
- `wechat://external-client-entrypoints`
- `wechat://validation-plan`

## Recommended Flow
1. Read the contract and inventory resources.
2. Read the read-order resource and follow the sequence it gives.
3. Read the consumer-router resource to choose the first safe consumer hop.
4. Read the path-conventions resource to keep paths repo-relative and clone-agnostic.
5. Read the prompt-selection-guide resource to choose the smallest safe prompt when drafting work.
6. Read the task-map resource to jump from a common task to the smallest helpful resource.
7. Use `tool_selection_guide` to pick the smallest safe tool when the path is unclear.
8. Use `generate_page_bundle` or `generate_component_bundle` for a draft prompt when you need a new bundle.
9. Validate with `validate_page_bundle`, `validate_component_bundle`, or `validate_app_json_patch`.
10. Apply only after validation passes.
11. For diagnosis and repair, inspect `wechat://latest-diagnostics-metrics` before retrying.
12. When the task is ambiguous, prefer `tool_selection_guide` over guessing a write tool.
13. Use `wechat://installer-readiness` when you need the installer-facing public distribution checklist.
14. Use `wechat://distribution-quickstart` when you need the shortest public-safe starting point for installer or consumer distribution work.
15. Use `wechat://registration-guidance` when you need the clone-agnostic registration guide for client setup.

## Guardrails
- Keep payloads repo-relative when possible.
- Do not bypass the boundary script for writes.
- Treat `server_inventory` as the fastest way to confirm the current surface.

# MCP Distribution Quickstart

## Purpose
Use this as the shortest public-safe starting point for installer-facing or consumer-facing distribution work.

## Portable Notes
- This quickstart is client-agnostic and does not depend on machine-local paths.
- Keep examples repo-relative and clone-agnostic.
- Treat `server.json` as the public-safe metadata summary, not as a runtime contract.
- Do not change the validate/apply contract when preparing distribution metadata.

## Read First
- `wechat://server-inventory`
- `wechat://read-order`
- `wechat://consumer-router`
- `wechat://installer-readiness`
- `wechat://registry-readiness`
- `wechat://distribution-quickstart`
- `wechat://registration-guidance`
- `wechat://surface-map`
- `wechat://tool-selection-guide`
- `wechat://client-usage-guide`
- `wechat://inspector-quickstart`

## Quick Path
1. Read `server_inventory` to confirm the live surface.
2. Read `read_order` to follow the repo's recommended first-pass sequence.
3. Read `consumer_router` to choose the first safe consumer hop.
4. Read `path_conventions` to keep paths repo-relative and clone-agnostic.
5. Read `installer_readiness` to confirm the installer-facing public checklist.
6. Read `registry_readiness` to confirm the registry-facing public checklist.
7. Read `registration_guidance` to confirm the clone-agnostic client registration pattern.
8. Read `surface_map` to jump from a public surface to the matching doc or test.
9. Read `tool_selection_guide` to pick the narrowest safe tool when the task is ambiguous.
10. Use the narrow smoke check for `scripts/wechat-mcp-server.mjs` before any publication-minded step.

## Notes
- This guide is additive and read-only.
- It is intended for clone-based usage and future distribution work.
- It does not enable publication by itself.

# MCP Registration Guidance

## Purpose
Use this guide when you want to register or consume this MCP surface in a clone-agnostic way.
This guide is installer-facing and consumer-facing.

## Portable Notes
- This guide is public-safe and does not depend on machine-local paths.
- Keep every example repo-relative.
- Treat `server.json` as the public metadata summary and `scripts/wechat-mcp-server.mjs` as the runtime surface.
- Do not change validate/apply contracts when preparing client registration.

## Registration Inputs
- `mcpName` from `package.json`
- `server.json` as the public-safe surface summary
- `scripts/wechat-mcp-server.mjs` as the stdio transport entry

## Clone-Agnostic Registration Pattern
1. Clone the repo.
2. Read `server.json` to confirm the live tools, prompts, and resources.
3. Run the server from the repo root with the stdio entry in `scripts/wechat-mcp-server.mjs`.
4. Point the MCP client at the repo root as the working directory, not at a machine-specific checkout path.
5. Prefer the read-only resources first:
   - `wechat://registration-guidance`
   - `wechat://server-inventory`
   - `wechat://read-order`
   - `wechat://consumer-router`
   - `wechat://installer-readiness`
   - `wechat://registry-readiness`
   - `wechat://distribution-quickstart`
6. Use `wechat://client-usage-guide` and `wechat://inspector-quickstart` to choose the smallest safe next hop.
7. Validate the live surface with the narrow smoke and inventory checks before treating the client registration as ready.

## Consumer Notes
- Use the smallest safe first hop from the read-only resources.
- Keep payloads repo-relative.
- Avoid rooted examples in client config and docs.
- If the surface changes, refresh `server.json` and re-run the narrow distribution tests.

## Notes
- This guide is additive and read-only.
- It prepares later registry or installer publication without inventing a publisher URL.

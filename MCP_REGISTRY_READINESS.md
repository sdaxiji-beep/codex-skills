# MCP Registry Readiness

## Purpose

This repo already exposes a public-safe MCP surface through:

- `package.json`
- `server.json`
- `scripts/wechat-mcp-server.mjs`

This guide explains how to keep that surface ready for future MCP registry or installer workflows without introducing machine-local assumptions.

## Current state

The repo currently provides:

- a public-safe `mcpName` in `package.json`
- a repo-root `server.json` summary for tools, resources, prompts, and transport
- a stdio entry at `scripts/wechat-mcp-server.mjs`
- clone-agnostic docs for inspector and consumer usage
- a clone-agnostic registration guide for installer/consumer setup

The repo does **not** assume a specific publisher, package registry, or Git hosting URL here.
The root `package.json` currently keeps `"private": true`, so the repo is registry-ready in structure but not yet configured for direct npm publication.

## Readiness rules

- Keep metadata repo-relative and machine-neutral.
- Do not add local checkout paths to examples.
- Do not change the stable validate/apply contract just to satisfy packaging metadata.
- Treat `server.json` as a summary of the exposed surface, not as a new runtime contract.

## Recommended read order

1. Read `server.json`
2. Read `MCP_INSPECTOR_QUICKSTART.md`
3. Read `MCP_CLIENT_USAGE.md`
4. Run the narrow smoke check for `scripts/wechat-mcp-server.mjs`

## Future publish prerequisites

Before any real registry or installer publication, confirm:

- `mcpName` is final
- `server.json` still matches the live MCP surface
- public docs still avoid machine-local paths
- smoke and inventory tests still pass
- release/package checks remain green

## Installer-facing checklist

If the next hop is an installer or registry publication path, keep the same public-safe shape and check these points before publishing:

- Use `server.json` as the public metadata summary.
- Use `scripts/wechat-mcp-server.mjs` as the clone-based runtime surface.
- Keep the consumer path repo-relative and machine-neutral.
- Expose `wechat://installer-readiness` as the read-only public hint for installer publication work.
- Do not introduce rooted local paths in examples or docs.

- Expose `wechat://registration-guidance` as the read-only public hint for clone-agnostic client registration.

## Notes

- This guide is additive and public-safe.
- It does not enable automatic publication.
- It keeps the current repo compatible with clone-based usage while preparing for later distribution work.

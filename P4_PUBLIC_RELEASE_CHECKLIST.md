# P4 Public Release Checklist

Use this checklist when preparing a public-safe GitHub upload from this workspace.

## Purpose

This checklist defines the current P4 public release surface:

- distribution-ready
- consumer-ready
- repo-relative
- public-safe

It is intentionally narrower than the full local workspace.

## Include

- `.agents/skills/`
- `.github/workflows/`
- `config/local-release.config.example.json`
- `config/page-elements.json`
- `diagnostics/`
- `specs/task-201-sandbox-dispatcher-proof.json`
- `specs/task-202-sandbox-create-file.json`
- `specs/task-203-sandbox-modify-rollback.json`
- `sandbox/`
- `scripts/`
- `templates/`
- `.gitignore`
- `README.md`
- `CLAUDE.md`
- `GOLDEN_PATH.md`
- `PHASE_PLAN.md`
- `RELEASE_PACKAGE.md`
- `RELEASE_FINAL_ACTIONS.md`
- `PUBLIC_API_SURFACE.md`
- `EXTERNAL_CLIENT_ENTRYPOINTS.md`
- `MCP_BOUNDARY_CONTRACT.md`
- `MCP_CLIENT_USAGE.md`
- `MCP_DISTRIBUTION_QUICKSTART.md`
- `MCP_INSPECTOR_QUICKSTART.md`
- `MCP_REGISTRATION_GUIDANCE.md`
- `MCP_REGISTRY_READINESS.md`
- `MCP_SURFACE_MAP.md`
- `MCP_TOOL_SELECTION.md`
- `TEST_TIERS.md`
- `P4_PUBLIC_RELEASE_CHECKLIST.md`
- `package.json`
- `package-lock.json`
- `server.json`
- `release-package.manifest.json`
- `probe-automator.js`
- `wechat-deploy.js`

## Exclude

- `artifacts/`
- `generated/`
- `node_modules/`
- `mcp/`
- `keys/`
- `config/local-release.config.json`
- `AGENTS.md`
- `PROJECT_STATE.md`
- `EXECUTION_CHECKLIST.md`
- root files or docs that exist only for local coordination
- any file that contains rooted personal paths or personal identifiers

## Spec handling

- keep public-safe specs only when they are intended as shareable examples
- exclude known local-only or previously withheld spec files
- do not include temporary task drafts or local experiment specs by default

## Validation before upload

Run these checks from the copied release folder:

```powershell
node --check .\scripts\wechat-mcp-server.mjs
powershell -ExecutionPolicy Bypass -File .\scripts\test-wechat-mcp-distribution-acceptance.ps1
powershell -ExecutionPolicy Bypass -File .\scripts\test-wechat-skill.ps1 -GuardCheckOnly
powershell -ExecutionPolicy Bypass -File .\scripts\test-wechat-skill.ps1 -SkipSmoke -Tag fast
```

## Hygiene rules

- keep every published example repo-relative
- do not publish machine-local absolute paths
- do not publish private config values
- do not publish runtime outputs
- do not publish legacy `mcp/` workspaces; publish only the repo-root MCP surface

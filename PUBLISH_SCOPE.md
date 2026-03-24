# Publish Scope

This file defines what should enter the next public GitHub update from `G:\codex_skills_releaseprep`.

## Status

Validated candidate baseline:
- guard-check: `141` scripts pass
- release-package check: pass
- fast: `70/70`
- full: `97/97`

Current repo state:
- branch: `codex/merge-master`
- relative to remote: `ahead 60`
- working tree: dirty

The repo is functionally ready, but publish work must be selective.

## Publish Now

These areas are the public product surface and should be considered in-scope for the next release:

- `.agents/skills/`
  - all 7 WeChat skills
- `mcp/wechat-devtools-mcp/`
- `mcp/wechat-devtools-mcp-write/`
- `scripts/`
  - runtime entrypoints
  - boundary/gate scripts
  - release/package checks
  - focused/fast/full regression tests
  - AST validator support files
- `templates/`
  - `notebook`
  - `todo`
  - `shoplist`
  - `template-map.json`
- root docs:
  - `README.md`
  - `RELEASE_PACKAGE.md`
  - `EXTERNAL_CLIENT_ENTRYPOINTS.md`
  - `MCP_BOUNDARY_CONTRACT.md`
  - `CLAUDE.md`
  - `GOLDEN_PATH.md`
  - `AST_VALIDATION_DESIGN.md`
  - `PUBLIC_READY_VERDICT.md`
  - `RELEASE_FINAL_ACTIONS.md`
  - `PHASE_PLAN.md`
- root runtime/package files:
  - `package.json`
  - `package-lock.json`
  - `wechat-deploy.js`
  - `release-package.manifest.json`
- public example config:
  - `config/local-release.config.example.json`

## Keep Local Only

These files or directories may exist locally but should not be published:

- `config/local-release.config.json`
- `generated/`
- `artifacts/`
- `node_modules/`
- MCP subproject `node_modules/`

Reason:
- local environment coupling
- runtime/test output
- machine-specific dependencies

## Do Not Publish In Public Mainline

These items are not required for the public product surface and should stay out of a clean public release unless intentionally documented:

- `specs/task-005-add-log-getOrder-v2.json`
- `specs/task-add-log-to-timer.json`

Reason:
- they are business-shaped task specs rather than general-purpose public capability examples

## Release Intent

The release should present this repo as:

- a controlled WeChat Mini Program generation workspace
- a skill-driven local orchestration system
- a boundary-first MCP/client integration surface

The release should not present this repo as:

- a dump of runtime artifacts
- a personal machine snapshot
- a business-specific spec archive

## Pre-Publish Rule

Before any push/tag/release action:

1. Review only publish-scope files.
2. Exclude local-only and business-specific artifacts.
3. Re-run:
   - `scripts\test-wechat-skill.ps1 -GuardCheckOnly`
   - `scripts\test-wechat-skill.ps1 -SkipSmoke -Tag fast`
   - `scripts\test-wechat-skill.ps1 -Tag full`
   - `scripts\check-release-package.ps1`

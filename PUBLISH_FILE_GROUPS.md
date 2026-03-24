# Publish File Groups

This file turns the release candidate into grouped commit scope so publish work can be staged cleanly.

## Group 1: Core Docs

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

Purpose:
- explain what the repo is
- explain how external agents call it
- explain release posture and validation flow

## Group 2: Skill Surface

- `.agents/skills/wechat-devtools-control/`
- `.agents/skills/wechat-page-generator/`
- `.agents/skills/wechat-component-generator/`
- `.agents/skills/wechat-global-config-modifier/`
- `.agents/skills/wechat-spec-executor/`
- `.agents/skills/wechat-release-guard/`
- `.agents/skills/wechat-lab-builder/`

Purpose:
- define the public agent behavior contracts

## Group 3: Runtime and Boundary

- `scripts/wechat.ps1`
- `scripts/wechat-mcp-tool-boundary.ps1`
- `scripts/generation-gate-v1.ps1`
- `scripts/generation-gate-component-v1.ps1`
- `scripts/generation-gate-ast-policy.ps1`
- `scripts/wechat-agentic-loop.ps1`
- `scripts/wechat-readonly-flow.ps1`
- `scripts/wechat-task-dispatch.ps1`
- `scripts/wechat-deploy.ps1`
- `scripts/mcp-write-preview.ps1`
- `scripts/mcp-write-deploy.ps1`
- `scripts/check-release-package.ps1`
- `scripts/validators/validate-bundle-ast.mjs`
- `wechat-deploy.js`

Purpose:
- provide the execution core behind the skill layer

## Group 4: MCP Servers

- `mcp/wechat-devtools-mcp/`
- `mcp/wechat-devtools-mcp-write/`

Purpose:
- expose reusable read/write operations for external clients

## Group 5: Templates

- `templates/notebook/`
- `templates/todo/`
- `templates/shoplist/`
- `templates/template-map.json`

Purpose:
- keep low-risk template generation available as the default landing path

## Group 6: Validation and Package Contract

- `release-package.manifest.json`
- `config/local-release.config.example.json`
- boundary/external-client/release-package/AST/golden-path focused tests in `scripts/`
- updated regression list in `scripts/test-wechat-skill.ps1`

Purpose:
- keep docs, contracts, and runtime behavior locked together

## Excluded From Public Commit Scope

- `config/local-release.config.json`
- `generated/`
- `artifacts/`
- `node_modules/`
- business-shaped specs under `specs/`

## Suggested Commit Strategy

1. Docs and release contract.
2. Skills and runtime boundary.
3. MCP/runtime/template/test updates.
4. Final validation rerun before push.

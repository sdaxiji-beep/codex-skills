# Public API Surface

Last updated: 2026-04-02

## Purpose

This repo contains many scripts for implementation, testing, diagnostics, and release checks.

Not all of them are public API.

Examples in this file use repo-relative paths so they stay clone-agnostic.

This document defines the supported public surface for:

- users
- external clients
- release-facing automation

## Public entrypoints

These are the supported public automation entrypoints.

### Human/operator entrypoint

- `scripts\wechat.ps1`

Use this when operating the repo directly in PowerShell.

Supported public functions include:

- `Invoke-WechatBootstrap`
- `Invoke-WechatDoctor`
- `Invoke-WechatCreate`
- `Invoke-WechatGeneratePage`
- `Invoke-WechatGenerateComponent`
- `Invoke-WechatPatchAppJson`
- `Get-GeneratedProjectList`
- `Invoke-GeneratedProjectOpen`
- `Invoke-GeneratedProjectPreview`
- `Invoke-GeneratedProjectDeployGuard`
- `Invoke-GeneratedProjectSetAppId`
- `Invoke-GeneratedProjectUpload`
- `Get-WechatValidationPlan`

### External client boundary entrypoint

- `scripts\wechat-mcp-tool-boundary.ps1`

Supported public operations:

- `describe_contract`
- `describe_execution_profile`
- `validate_page_bundle`
- `apply_page_bundle`
- `validate_component_bundle`
- `apply_component_bundle`
- `validate_app_json_patch`
- `apply_app_json_patch`

### Diagnostics operator entrypoint

- `diagnostics\Invoke-RepairLoopAuto.ps1`

Use this for controlled detect -> repair -> re-check loops.

## Public docs

These files are part of the public contract surface:

- `README.md`
- `CLAUDE.md`
- `MCP_BOUNDARY_CONTRACT.md`
- `EXTERNAL_CLIENT_ENTRYPOINTS.md`
- `TEST_TIERS.md`
- `RUNTIME_RETENTION_POLICY.md`
- `RELEASE_PACKAGE.md`

## Distribution metadata

The repo-root distribution metadata is public-safe and additive, but it is not a runtime API contract.

Current public-safe metadata summary:

- `package.json` advertises the MCP package name through `mcpName`
- `server.json` summarizes the repo-relative MCP distribution surface
- `MCP_CLIENT_USAGE.md` and `MCP_INSPECTOR_QUICKSTART.md` document the consumer-facing path
- `MCP_REGISTRY_READINESS.md` documents the repo-relative installer and registry readiness guidance
- `wechat://installer-readiness` is the read-only public hint for installer-facing registration guidance

Keep this metadata repo-relative and machine-neutral. It should describe how to discover the surface, not introduce new validate/apply behavior.
Installer-facing guidance remains documentation-only and does not change the public required-checks stance or the stable validate/apply contract surface.

## Public skills

These skills are part of the supported public skill surface:

- `.agents\skills\wechat-devtools-control`
- `.agents\skills\wechat-release-guard`
- `.agents\skills\wechat-spec-executor`
- `.agents\skills\wechat-lab-builder`

## Internal implementation surface

These are important, but should not be presented as stable public API:

- `scripts\generation-gate-*.ps1`
- `scripts\wechat-apply-*.ps1`
- `scripts\wechat-readonly-flow.ps1`
- `scripts\wechat-agentic-loop.ps1`
- `scripts\wechat-task-dispatch.ps1`
- `diagnostics\Invoke-*.ps1` except `Invoke-RepairLoopAuto.ps1`

These files can evolve more aggressively as internal implementation.

## Test-only surface

The following are regression/support files and are not public API:

- `scripts\test-*.ps1`
- `diagnostics\Test-*.ps1`

## Support statement

Supported public usage means:

- the command or contract is documented
- it is expected to remain stable across normal repo evolution
- changes should be reflected in docs and regression coverage

Compatibility note:

- `scripts\wechat-mcp-tool-boundary.ps1` is the stable public boundary for external clients.
- `scripts\test-*.ps1` and `diagnostics\Test-*.ps1` remain test-only and may change more aggressively.
- `diagnostics\Invoke-RepairLoopAuto.ps1` is a supported operator entrypoint, but its repair heuristics are still expected to evolve.
- External clients should prefer documented boundary operations over internal implementation scripts.

Internal files may still be useful for development, but they are not part of the public compatibility promise.

## CI scope

GitHub CI is intentionally limited to repo-safe guard rails and diagnostics-focused checks.
Local Windows + WeChat DevTools validation remains required for `fast`, `full`, and any real preview/deploy confirmation.
See `README.md` and `RELEASE_PACKAGE.md` for the repo-relative local-vs-CI matrix.
That matrix is advisory for public sharing and does not change the stable boundary contract surface.
Public examples should remain repo-relative so they stay clone-agnostic on fresh copies of the repo.
Installer-facing guidance stays in the docs layer; it should not introduce any private checkout paths or contract changes.
The registry-readiness guide is additive only; it does not promote `fast` or `full` into GitHub-hosted required checks.

Recommended governance note:

- if the repository uses required checks or a ruleset, prefer keeping `ci-minimal / guardrails` and `ci-diagnostics / diagnostics-focused` required
- do not mark `fast`, `full`, or real preview/deploy drills as GitHub-hosted required checks because they remain local Windows + WeChat DevTools validation

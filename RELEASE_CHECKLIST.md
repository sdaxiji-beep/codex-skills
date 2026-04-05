# Release Checklist

Version target: `v2.1.0-rc.1`

## Before publishing to GitHub

1. Confirm version alignment:
   - `package.json`
   - `server.json`
   - `CHANGELOG.md`
   - `README.md`
   - `PROJECT_STATE.md`
2. Run local package simulation:
   - `npm pack --dry-run --json`
3. Confirm package includes:
   - `schemas/`
   - `assets/`
   - `docs/`
4. Confirm package excludes:
   - `keys/`
   - `config/local-release.config.json`
   - `artifacts/`
   - `generated/`
   - `sandbox/`
   - `diagnostics/screenshot/captures/`
5. Run local validation:
   - `scripts\test-wechat-skill.ps1 -GuardCheckOnly`
   - `scripts\test-p5-e2e-simplified-drill.ps1`
6. Review release notes:
   - `docs\release_description_rc1.md`
   - `CHANGELOG.md`
   - `docs\system_capabilities.md`
7. Confirm no contract changes were introduced to:
   - `scripts\wechat-mcp-tool-boundary.ps1`

## Packaging acceptance goals

- package surface is release-safe
- no local secrets or runtime debris are included
- registry-first internal pipeline remains documented
- release candidate marker is consistent everywhere

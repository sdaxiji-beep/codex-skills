# Release Final Actions

Last updated: 2026-03-24

Use this list when deciding whether to keep the repo private, ship a release candidate, or publish publicly.

## Current technical status

- Layer 0: `148` scripts pass
- fast: `70/70`
- full: `97/97`
- release package candidate: pass
- external-client boundary dry-run: pass
- external-client boundary-only release drill: pass

## Release decision options

### Option A: keep as local release candidate

Use this if you want to preserve the current state without publishing yet.

Actions:

1. Keep the repo private.
2. Keep `config/local-release.config.json` local only.
3. Keep using `PUBLIC_READY_VERDICT.md` and `README.md` as the working release summary.

### Option B: publish `v1.0.0-rc.1`

Use this if you want outside users to start testing the workflow while keeping expectations conservative.

Actions:

1. Re-run:
   - `scripts\test-wechat-skill.ps1 -GuardCheckOnly`
   - `scripts\test-wechat-skill.ps1 -SkipSmoke -Tag fast`
   - `scripts\test-wechat-skill.ps1 -Tag full`
   - `scripts\check-release-package.ps1`
2. Confirm no local private files are included:
   - `config/local-release.config.json`
   - any private key file
   - runtime-only generated outputs you do not want to ship
3. Publish with release notes based on:
   - `README.md`
   - `PUBLIC_READY_VERDICT.md`

### Option C: public mainline share

Use this only if you want the current repo to serve as the public default branch for other users.

Actions:

1. Make sure the public entry is clearly boundary-first:
   - `scripts\wechat-mcp-tool-boundary.ps1`
   - `EXTERNAL_CLIENT_ENTRYPOINTS.md`
2. Keep preview-first policy explicit.
3. Keep real release configuration local-only.
4. Treat cross-platform support as not yet promised.

## Final pre-publish checks

1. Verify release package hygiene:
   - `powershell -ExecutionPolicy Bypass -File .\scripts\check-release-package.ps1`
2. Verify public docs:
   - `README.md`
   - `EXTERNAL_CLIENT_ENTRYPOINTS.md`
   - `MCP_BOUNDARY_CONTRACT.md`
   - `PUBLIC_READY_VERDICT.md`
3. Verify release posture:
   - generated projects stay preview-first
   - `touristappid` stays blocked from upload/deploy
   - only local private config can unlock real release

## Recommended default

The best current posture is:

- keep the repo in release-candidate mode
- label the current state as `v1.0.0-rc.1`
- let outside users adopt the boundary-first workflow
- avoid promising cross-platform support yet

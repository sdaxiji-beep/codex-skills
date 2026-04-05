# Release Package Checklist

Use this checklist before sharing the project with other users.

## Include

- `scripts/`
- `templates/`
- `.agents/skills/wechat-devtools-control/SKILL.md`
- `README.md`
- `RELEASE_PACKAGE.md`
- `MCP_REGISTRY_READINESS.md`
- `EXTERNAL_CLIENT_ENTRYPOINTS.md`
- `MCP_BOUNDARY_CONTRACT.md`
- `server.json`
- `release-package.manifest.json`
- `config/local-release.config.example.json`
- `package.json`

## Exclude

- `artifacts/` runtime outputs
- `generated/` user-generated projects
- `diagnostics/screenshot/captures/` local screenshot captures
- `node_modules/`
- `keys/` and any private credential files
- `config/local-release.config.json`
- root `deploy-config.json`
- temporary restore folders (for example `restored-*`)

## Release policy

- Default generated projects to preview-only.
- Keep `touristappid` projects blocked from upload/deploy.
- Only allow guarded upload after a user sets a real appid intentionally.
- Treat runtime outputs as disposable local state and clean them with `scripts\cleanup-runtime-data.ps1` when needed.

## Runtime cleanup

Dry-run:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\cleanup-runtime-data.ps1"
```

Apply:

```powershell
powershell -ExecutionPolicy Bypass -File ".\scripts\cleanup-runtime-data.ps1" -Apply
```
- Real release actions should use a local private config file at `config/local-release.config.json`.
- Public sharing should include only `config/local-release.config.example.json`, never the private local config.

## First-run steps for other users

These commands are repo-relative and should work from any clone.

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\\wechat.ps1")
Invoke-WechatBootstrap
Invoke-WechatDoctor
Invoke-WechatCreate -Prompt "build a notebook mini program" -Open $false -Preview $false
```

## Validation gate before release

| Check | GitHub CI | Local Windows + DevTools |
| --- | --- | --- |
| `GuardCheckOnly` | Yes | Yes |
| `test-diagnostics-focused.ps1` | Yes | Yes |
| `fast` | No | Yes |
| `full` | No | Yes |
| Real preview / deploy drills | No | Yes |
| Release candidate gating | Public-safe only | Required |

GitHub CI is a public-safe gate only; local Windows + WeChat DevTools checks still remain required for the full release candidate.
Treat `fast`, `full`, and real preview/deploy drills as required local release-candidate validation on a Windows + WeChat DevTools machine.
Keep the public examples repo-relative so a shared package never depends on a local machine path.

```powershell
$RepoRoot = (Get-Location).Path
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\\test-wechat-skill.ps1") -GuardCheckOnly
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\\test-diagnostics-focused.ps1")
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\\test-wechat-skill.ps1") -SkipSmoke -Tag fast
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\\test-release-package-candidate.ps1")
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\\check-release-package.ps1")
```

Release candidates should have both GitHub diagnostics checks and local `fast/full` checks green.

Recommended repository ruleset / required checks:

- `ci-minimal / guardrails`
- `ci-diagnostics / diagnostics-focused`
- keep local `fast`, `full`, and real preview/deploy drills as release-candidate obligations, not GitHub-hosted required checks
`test-release-package-candidate.ps1` is a mandatory release check and now includes diagnostics quickcheck pass + diagnostics artifact contract verification.

## Distribution metadata

`server.json` is the repo-root distribution metadata summary for the MCP surface.
It is public-safe, repo-relative, and additive.
Use it together with `package.json` and the MCP usage guides when preparing a shareable package.
`MCP_REGISTRY_READINESS.md` is the installer-facing companion guide for public-safe registry and package preparation.
`wechat://installer-readiness` is the read-only public hint for installer-facing registration guidance.
When you share a package, keep the GitHub required-checks guidance public-safe: `ci-minimal / guardrails` and `ci-diagnostics / diagnostics-focused` remain hosted checks, while `fast` and `full` stay local Windows + DevTools obligations.

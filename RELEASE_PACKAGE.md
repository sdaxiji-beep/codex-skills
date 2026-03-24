# Release Package Checklist

Use this checklist before sharing the project with other users.

## Include

- `scripts/`
- `templates/`
- `.agents/skills/wechat-devtools-control/SKILL.md`
- `README.md`
- `RELEASE_PACKAGE.md`
- `EXTERNAL_CLIENT_ENTRYPOINTS.md`
- `MCP_BOUNDARY_CONTRACT.md`
- `release-package.manifest.json`
- `config/local-release.config.example.json`
- `package.json`

## Exclude

- `artifacts/` runtime outputs
- `generated/` user-generated projects
- `node_modules/`
- `keys/` and any private credential files
- `config/local-release.config.json`
- root `deploy-config.json`
- temporary restore folders (for example `restored-*`)

## Release policy

- Default generated projects to preview-only.
- Keep `touristappid` projects blocked from upload/deploy.
- Only allow guarded upload after a user sets a real appid intentionally.
- Real release actions should use a local private config file at `config/local-release.config.json`.
- Public sharing should include only `config/local-release.config.example.json`, never the private local config.

## First-run steps for other users

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\\wechat.ps1")
Invoke-WechatBootstrap
Invoke-WechatDoctor
Invoke-WechatCreate -Prompt "build a notebook mini program" -Open $false -Preview $false
```

## Validation gate before release

```powershell
$RepoRoot = (Get-Location).Path
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\\test-wechat-skill.ps1") -GuardCheckOnly
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\\test-wechat-skill.ps1") -SkipSmoke -Tag fast
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\\check-release-package.ps1")
```

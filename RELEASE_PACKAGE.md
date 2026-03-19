# Release Package Checklist

Use this checklist before sharing the project with other users.

## Include

- `scripts/`
- `templates/`
- `specs/` (only public/sample specs)
- `.agents/skills/wechat-devtools-control/SKILL.md`
- `README.md`
- `RELEASE_PACKAGE.md`
- `package.json`

## Exclude

- `artifacts/` runtime outputs
- `generated/` user-generated projects
- `node_modules/`
- `keys/` and any private credential files
- temporary restore folders (for example `restored-*`)

## Release policy

- Default generated projects to preview-only.
- Keep `touristappid` projects blocked from upload/deploy.
- Only allow guarded upload after a user sets a real appid intentionally.

## First-run steps for other users

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\\wechat.ps1")
Invoke-WechatBootstrap
Invoke-WechatDoctor
Invoke-WechatCreate -Prompt "build a notebook mini program" -Open $true -Preview $true
```

## Validation gate before release

```powershell
$RepoRoot = (Get-Location).Path
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\\test-wechat-skill.ps1") -GuardCheckOnly
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\\test-wechat-skill.ps1") -SkipSmoke -Tag fast
```

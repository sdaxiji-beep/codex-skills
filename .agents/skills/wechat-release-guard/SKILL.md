---
name: wechat-release-guard
description: Use this skill for guarded release actions in this repo, including preview, upload, and cloud deploy. Always run validation first, require explicit confirmation, verify results, and record outputs.
---

# WeChat Release Guard

Use this skill for release-only workflows. Do not use it for feature implementation.

## Required sequence

1. Run validation.
2. Require explicit confirmation.
3. Execute release command.
4. Verify release result.
5. Persist release records.

## Entry

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")

powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\test-wechat-skill.ps1") -SkipSmoke
Invoke-WechatPreview -RequireConfirm $true
Invoke-WechatUpload -RequireConfirm $true
Invoke-DeployCloudFunction -FuncName "<name>" -RequireConfirm $true
Invoke-DeployChangedCloudFunctions -RequireConfirm $true
```

## Safety rules

- Never skip validation before release actions.
- Never auto-deploy without explicit confirmation.
- Never modify business code during release-only requests.


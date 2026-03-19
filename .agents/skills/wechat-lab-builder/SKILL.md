---
name: wechat-lab-builder
description: Use this skill for experimental changes that must stay in lab paths only (sandbox/test workspaces) and must never modify production project code.
---

# WeChat Lab Builder

Use this skill when the user wants to experiment safely without touching production code.

## Safe paths

- `G:\codex专属\sandbox\fake-project`
- `G:\codex测试`

## Entry

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")

Invoke-SafeWrite `
  -ProjectPath (Join-Path $RepoRoot "sandbox\fake-project") `
  -Description "lab: <change>" `
  -RequireConfirm $false `
  -WriteAction { <edit action> }
```

```powershell
$RepoRoot = (Get-Location).Path
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\test-wechat-skill.ps1") -SkipSmoke -Tag fast
```

## Hard rules

- Never write to production project code in lab mode.
- Use guarded write helpers instead of raw writes.
- Keep deploy actions out of lab requests unless explicitly requested.


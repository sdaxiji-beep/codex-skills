---
name: wechat-devtools-control
description: >
  Use this skill for any WeChat Mini Program task in this
  repo when no narrower skill applies. Trigger on: bootstrap,
  doctor check, create project from prompt, preview generated
  project, run validation gates, guarded deploy orchestration.
  Narrower skills take priority: wechat-spec-executor,
  wechat-release-guard, wechat-lab-builder.
---

# WeChat DevTools Control

Use this fallback umbrella skill for the local WeChat workflow when a narrower WeChat skill is not explicitly selected.

## Entry
# Must run from repo root. Example: cd G:\codex_skills

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")
```

## Main workflow

```powershell
Invoke-WechatBootstrap
Invoke-WechatDoctor
Invoke-WechatCreate -Prompt "build a notebook mini program" -Open $true -Preview $true
```

## Generated project operations

```powershell
Get-GeneratedProjectList
Invoke-GeneratedProjectOpen
Invoke-GeneratedProjectPreview
Invoke-GeneratedProjectDeployGuard
Invoke-GeneratedProjectSetAppId
Invoke-GeneratedProjectUpload -DryRun $true
```

## Validation

```powershell
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\test-wechat-skill.ps1") -GuardCheckOnly
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\test-wechat-skill.ps1") -SkipSmoke -Tag fast
```

## Safety defaults

- Keep generated projects preview-first by default.
- Block deploy/upload for `touristappid` projects.
- Allow guarded upload/deploy only after setting a real appid and passing checks.
- Keep broad write/deploy routes disabled unless explicitly requested.

## Prefer narrower skills when appropriate

- `wechat-spec-executor`
- `wechat-release-guard`
- `wechat-lab-builder`

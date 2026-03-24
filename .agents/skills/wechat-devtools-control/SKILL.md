---
name: wechat-devtools-control
description: Use this skill for end-to-end WeChat DevTools workflow control in this repo, including bootstrap, environment doctor checks, natural-language project creation, generated project preview/guard/upload dry-run, validation gates (fast/full), and guarded deploy orchestration when no narrower WeChat skill applies.
---

# WeChat DevTools Control

Use this fallback umbrella skill for the local WeChat workflow when a narrower WeChat skill is not explicitly selected.

## Entry

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

## AutoFix loop policy (required)

When the user asks for "generate and make it correct", this skill must follow a repair loop and must not report success early.

1. Generate/update the target project code.
2. Run detector round (`automator` preferred; fallback route allowed).
3. If any issue is found, produce and apply a repair change.
4. Re-run detector round.
5. Repeat until:
   - success: checks pass, or
   - blocked: runtime/environment blocker, or
   - failed: max rounds reached.

Hard rule:
- Do not return `success` while known issues remain.
- Do not wait for extra user feedback between loop rounds unless the state is `blocked`.
- Runtime blockers (for example invalid appid, automator startup failure) must be surfaced explicitly as `blocked`, not hidden as pass.

## Compile error gate (required)

After project open/startup, compile/runtime parse errors in DevTools must be treated as blocking issues, not as startup success.

Examples:
- WXML parse errors such as `unexpected token` / `Bad value with message`
- file-level compile errors like `at files://...wxml`
- JS runtime load failures that stop page render

Required behavior:
1. Run a post-open detection round before declaring success.
2. If compile error evidence exists, classify as issue (critical), enter repair loop, and re-check.
3. Only return success when compile errors are cleared and detector result is healthy.
4. Collect console logs into `artifacts\wechat-devtools\console\latest.log` and evaluate them in every repair round.

## Prefer narrower skills when appropriate

- `wechat-spec-executor`
- `wechat-release-guard`
- `wechat-lab-builder`

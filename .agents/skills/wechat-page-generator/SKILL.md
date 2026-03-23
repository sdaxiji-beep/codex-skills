---
name: wechat-page-generator
description: >
  Use this skill to generate or implement a specific WeChat Mini Program
  page in this repo after a page-generation spec has been created.
  Trigger on: page-level implementation, JSON bundle generation,
  Generation Gate retries, and applying validated page files through
  scripts\wechat-apply-bundle.ps1.
---

# WeChat Page Generator

Use this skill for page-level generation only. Do not use it for full project bootstrapping, preview orchestration, or release operations.

## Entry

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")
Invoke-WechatGeneratePage -Prompt "<page requirement>" -PagePath "pages/<page>/index"
```

## Workflow

1. Read the generated spec from `.agents\tasks\page-generation-spec-*.md`.
2. Read the exact bundle output path from that spec.
3. Create a single JSON bundle at that exact dynamic bundle path. Do not hardcode `temp_bundle.json`.
4. Keep the bundle page-scoped:
   - `pages/<page>/index.wxml`
   - `pages/<page>/index.js`
   - `pages/<page>/index.wxss`
   - `pages/<page>/index.json`
5. Apply the bundle with the command pattern recorded in the spec:

```powershell
$RepoRoot = (Get-Location).Path
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\wechat-apply-bundle.ps1") -JsonFilePath "<bundle-path-from-spec>" -TargetWorkspace "<workspace-from-spec>"
```

## Autonomous Directives

- Do not stop after a retryable validation failure.
- Do not ask the user for help or permission when the Generation Gate returns exit code `1`.
- Read stderr, fix the exact reported issues in the JSON bundle, and run the apply command again.
- Continue this self-repair loop until the bundle passes or the gate returns exit code `2`.
- If exit code `2` occurs, stop and report the boundary violation to the user.

## Generation Rules

- Generate only page-level files under `pages/`.
- If the spec lists available custom components, use only those listed tags and exact import paths.
- When using a custom component, register it in `usingComponents` with the exact `/components/<name>/index` path named in the spec.
- Never modify `app.js`, `app.json`, `app.wxss`, `project.config.json`, `scripts/`, or `templates/`.
- Use WeChat tags only in WXML.
- Wrap page logic in `Page({ ... })`.
- Use `wx.*` APIs only. Never use `document`, `window`, `localStorage`, `fetch`, or `axios`.
- Prefer `rpx` in WXSS.

## Retry Contract

- Exit code `0`: apply succeeded.
- Exit code `1`: this is retryable. Do not ask the user for help. Fix every listed validation error, rewrite the JSON bundle at the same dynamic bundle path, and retry immediately.
- Exit code `2`: boundary violation. Abort instead of retrying.

## Use Narrower/Other Skills Instead When Needed

- Use `wechat-devtools-control` for bootstrap, doctor, create-project, preview, or generated-project operations.
- Use `wechat-release-guard` for preview/upload/deploy steps.
- Use `wechat-spec-executor` for structured repo specs outside this page-generation flow.

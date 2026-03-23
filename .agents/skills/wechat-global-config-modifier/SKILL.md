---
name: wechat-global-config-modifier
description: >
  Use this skill to modify WeChat Mini Program global routing config in
  this repo through an append-only app.json patch spec. Trigger on:
  registering generated pages in app.json, append_pages patch creation,
  app.json patch validation retries, and applying validated patches
  through scripts\wechat-apply-app-json-patch.ps1.
---

# WeChat Global Config Modifier

Use this skill only for the V1 app.json patch flow. Do not use it for page generation, component generation, project bootstrap, preview, or release operations.

## Entry

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")
Invoke-WechatPatchAppJson -Prompt "<routing intent>" -PagePaths "pages/<page>/index"
```

## Workflow

1. Read the generated patch spec from `.agents\tasks\app-json-patch-spec-*.md`.
2. Read the exact patch output path from that spec.
3. Create a single JSON patch at that exact path.
4. Keep the patch inside the V1 contract:
   - top-level field: `append_pages`
   - values: `pages/<page>/index`
5. Apply the patch with the command pattern recorded in the spec:

```powershell
$RepoRoot = (Get-Location).Path
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\wechat-apply-app-json-patch.ps1") -JsonFilePath "<patch-path-from-spec>" -TargetWorkspace "<workspace-from-spec>"
```

## Patch Rules

- Do not output full `app.json` content.
- Do not output `files[]`.
- Do not add keys other than `append_pages`.
- Use page paths with no file extension.
- Register only real page paths listed in the spec.
- Never modify `app.js`, `app.wxss`, `project.config.json`, `scripts/`, or `templates/`.

## Autonomous Directives

- Do not stop after a retryable validation failure.
- Do not ask the user for help or permission when the app.json gate returns exit code `1`.
- Read stderr, fix the exact reported issues in the JSON patch, and run the apply command again.
- Continue this self-repair loop until the patch passes or the gate returns exit code `2`.
- If exit code `2` occurs, stop and report the boundary violation to the user.

## Retry Contract

- Exit code `0`: patch applied successfully.
- Exit code `1`: this is retryable. Fix every listed validation error, rewrite the same patch file, and retry immediately.
- Exit code `2`: boundary violation. Abort instead of retrying.

## Use Other Skills Instead When Needed

- Use `wechat-page-generator` for `pages/**` generation.
- Use `wechat-component-generator` for `components/**` generation.
- Use `wechat-devtools-control` for bootstrap, doctor, create-project, preview, or generated-project operations.
- Use `wechat-release-guard` for preview/upload/deploy steps.

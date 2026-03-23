---
name: wechat-component-generator
description: >
  Use this skill to generate or implement a WeChat Mini Program custom
  component in this repo after a component-generation spec has been
  created. Trigger on: component-level implementation, JSON bundle
  generation for components, Component Generation Gate retries, and
  applying validated component files through
  scripts\wechat-apply-component-bundle.ps1.
---

# WeChat Component Generator

Use this skill for custom component generation only. Do not use it for full project bootstrapping, page generation, preview orchestration, or release operations.

## Entry

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")
Invoke-WechatGenerateComponent -Prompt "<component requirement>" -ComponentPath "components/<component>/index"
```

## Workflow

1. Read the generated component spec from `.agents\tasks\COMPONENT_SPEC_*.md`.
2. Read the exact bundle output path from that spec.
3. Create a single JSON bundle at that exact dynamic bundle path. Do not hardcode `temp_bundle.json`.
4. Keep the bundle component-scoped:
   - `components/<component>/index.wxml`
   - `components/<component>/index.js`
   - `components/<component>/index.wxss`
   - `components/<component>/index.json`
5. Apply the bundle with the command pattern recorded in the spec:

```powershell
$RepoRoot = (Get-Location).Path
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\wechat-apply-component-bundle.ps1") -JsonFilePath "<bundle-path-from-spec>" -TargetWorkspace "<workspace-from-spec>"
```

## Component Sandbox

- Generate files only inside a single-level component directory such as `components/product-card/`.
- Never modify `app.js`, `app.json`, `app.wxss`, `project.config.json`, `pages/**`, `scripts/`, or `templates/`.
- Do not write multi-level component paths such as `components/a/b/index.*` in V1.

## Component Rules

- Use `Component({ ... })`. Never use `Page({ ... })`.
- Declare a `properties` object inside `Component({ ... })`, even if it is empty.
- Keep property types to `String`, `Number`, `Boolean`, `Object`, `Array`, or `null`.
- Require `"component": true` in the component JSON config.
- Do not include page-only JSON keys such as `pages`, `window`, or `navigationBarTitleText`.
- Use WeChat component tags only in WXML, plus `<slot>` and `<block>`.
- Never use HTML tags such as `<div>`, `<span>`, `<a>`, or `<p>`.
- Prefer `rpx` in WXSS.
- Never use global selectors such as `page`, `body`, or `html` in component WXSS.
- Use `wx.*` APIs only. Never use `document`, `window`, `localStorage`, `fetch`, or `axios`.

## Output Format

- Do not output scattered code blocks.
- Return a single valid JSON object written to the bundle file path named in the spec.
- Include `component_name` and `files[]`.

## Autonomous Retry Loop

- Exit code `0`: the component was validated and written successfully.
- Exit code `1`: this is retryable.
  - Do not stop.
  - Do not ask the user for help or permission.
  - Read stderr.
  - Fix the exact reported issues in the JSON bundle.
  - Overwrite the same bundle file.
  - Run the apply command again.
  - Repeat until the bundle passes or the gate returns exit code `2`.
- Exit code `2`: boundary violation. Abort and inform the user.

## Use Other Skills Instead When Needed

- Use `wechat-devtools-control` for bootstrap, doctor, create-project, preview, or generated-project operations.
- Use `wechat-page-generator` for `pages/**` generation.
- Use `wechat-release-guard` for preview/upload/deploy steps.
- Use `wechat-spec-executor` for structured repo specs outside this component-generation flow.

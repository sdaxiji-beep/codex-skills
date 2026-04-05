---
name: wechat-spec-executor
description: Use this skill to execute JSON task specs in this repo through validate, write, deploy, and record stages using the existing script pipeline.
---

# WeChat Spec Executor

Use this skill when the user asks to run a spec file or execute a structured task definition.

## Entry

```powershell
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")
Invoke-AgenticLoopFromSpec -SpecPath (Join-Path $RepoRoot "specs\<task-file>.json")
```

## Rules

- Read the spec before execution.
- Respect spec-defined validation, record, and rollback fields.
- Keep write/deploy confirmation enabled for real projects.
- For natural-language requests, handoff to task dispatch first:

```powershell
Invoke-WechatTask -HandoffOnly "<request>"
```

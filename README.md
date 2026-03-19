# codex_skills

Codex skill workspace for building WeChat Mini Programs from natural language.

Use this repo when you want Codex to:
- create a mini program from a prompt
- run environment checks before work starts
- preview generated projects in WeChat DevTools
- keep real upload/deploy guarded behind a local release setup

This repo is a standalone workspace copied from the original workspace and packaged so the skills, scripts, templates, and validation flow work together.

## Requirements

- Windows
- PowerShell
- WeChat DevTools installed locally
- Codex desktop or another Codex environment that can read local skill folders

## What Is Included

- `/.agents/skills/`
  - `wechat-devtools-control`
  - `wechat-release-guard`
  - `wechat-spec-executor`
  - `wechat-lab-builder`
- `/scripts`
- `/templates`
- `/config`
- `/mcp` copied without `node_modules`

## What Is Not Included

- `/generated`
- `/artifacts`
- `/keys`
- runtime cache
- local audit output

## Quick Start

```powershell
cd G:\codex_skills
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")
Invoke-WechatBootstrap
Invoke-WechatDoctor
Invoke-WechatCreate -Prompt "build a notebook mini program" -Open $true -Preview $true
```

That sequence is the shortest path from prompt to preview.

## Install Options

### Option A: Use this repo as a full workspace

Recommended if you want the skills and the scripts/templates to work together immediately.

```powershell
cd G:\codex_skills
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")
```

Then run:

```powershell
Invoke-WechatBootstrap
Invoke-WechatDoctor
Invoke-WechatCreate -Prompt "build a notebook mini program" -Open $true -Preview $true
```

### Option B: Install only the skills into your own Codex skill directory

Use this only if you already have an equivalent local workspace with matching `scripts`, `templates`, `config`, and `mcp` paths.

Copy these folders into your Codex skills directory:

- `G:\codex_skills\.agents\skills\wechat-devtools-control`
- `G:\codex_skills\.agents\skills\wechat-release-guard`
- `G:\codex_skills\.agents\skills\wechat-spec-executor`
- `G:\codex_skills\.agents\skills\wechat-lab-builder`

If you install only the skill folders but not the supporting workspace, the skills may load correctly but fail at runtime because the expected local scripts are missing.

## Recommended Usage

For normal use, do not memorize commands. Ask Codex in natural language, for example:

- "Help me create a notebook mini program and preview it."
- "Run a WeChat environment doctor check."
- "Open the latest generated project."

The commands remain available for debugging, documentation, or manual operation.

## Validate Skills

```powershell
python "C:\Users\Laptop\.codex\skills\.system\skill-creator\scripts\quick_validate.py" `
  "G:\codex_skills\.agents\skills\wechat-devtools-control"
python "C:\Users\Laptop\.codex\skills\.system\skill-creator\scripts\quick_validate.py" `
  "G:\codex_skills\.agents\skills\wechat-release-guard"
python "C:\Users\Laptop\.codex\skills\.system\skill-creator\scripts\quick_validate.py" `
  "G:\codex_skills\.agents\skills\wechat-spec-executor"
python "C:\Users\Laptop\.codex\skills\.system\skill-creator\scripts\quick_validate.py" `
  "G:\codex_skills\.agents\skills\wechat-lab-builder"
```

## Default Behavior

- Generated projects are preview-first by default.
- `touristappid` projects stay blocked from upload and deploy.
- Real upload is only for explicit real-appid cases after guard checks.
- If real deploy config is missing, use `Invoke-WechatReleaseSetup` to collect local appid and private key settings on the user's machine.

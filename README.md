# codex_skills

Standalone WeChat skill workspace extracted from `G:\codex专属`.

This repo is for Codex users who want reusable WeChat Mini Program skills together with the supporting scripts and templates those skills expect.

## Environment

- Windows
- PowerShell
- WeChat DevTools installed locally
- Codex desktop or another Codex environment that can read local skill folders

## What this repo contains

- `/.agents/skills/`
  - `wechat-devtools-control`
  - `wechat-release-guard`
  - `wechat-spec-executor`
  - `wechat-lab-builder`
- `/scripts`
- `/templates`
- `/config`
- `/mcp` copied without `node_modules`

## What this repo does not include

- `/generated`
- `/artifacts`
- `/keys`
- runtime cache
- local audit output

## Install options

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

## Recommended usage

For normal use, do not memorize commands. Ask Codex in natural language, for example:

- "Help me create a notebook mini program and preview it."
- "Run a WeChat environment doctor check."
- "Open the latest generated project."

The commands remain available for debugging, documentation, or manual operation.

## Validate skills

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

## Default behavior

- Generated projects are preview-first by default.
- `touristappid` projects stay blocked from upload and deploy.
- Real upload is only for explicit real-appid cases after guard checks.
- If real deploy config is missing, use `Invoke-WechatReleaseSetup` to collect local appid and private key settings on the user's machine.

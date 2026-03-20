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
cd <your-cloned-repo-path>
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")
Invoke-WechatBootstrap
Invoke-WechatDoctor
Invoke-WechatCreate -Prompt "build a notebook mini program" -Open $true -Preview $true
```

That sequence is the shortest path from prompt to preview. The repo does not need to live on `G:` as long as you run the commands from the cloned workspace root.

## Install Options

### Option A: Use this repo as a full workspace

Recommended if you want the skills and the scripts/templates to work together immediately.

```powershell
cd <your-cloned-repo-path>
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

- `<repo-root>\.agents\skills\wechat-devtools-control`
- `<repo-root>\.agents\skills\wechat-release-guard`
- `<repo-root>\.agents\skills\wechat-spec-executor`
- `<repo-root>\.agents\skills\wechat-lab-builder`

If you install only the skill folders but not the supporting workspace, the skills may load correctly but fail at runtime because the expected local scripts are missing.

## Recommended Usage

For normal use, do not memorize commands. Ask Codex in natural language, for example:

- "Help me create a notebook mini program and preview it."
- "Run a WeChat environment doctor check."
- "Open the latest generated project."

The commands remain available for debugging, documentation, or manual operation.

## Validate Skills

```powershell
$RepoRoot = (Get-Location).Path
$Validator = "<path-to-your-Codex-skill-creator>\\scripts\\quick_validate.py"

python $Validator (Join-Path $RepoRoot ".agents\skills\wechat-devtools-control")
python $Validator (Join-Path $RepoRoot ".agents\skills\wechat-release-guard")
python $Validator (Join-Path $RepoRoot ".agents\skills\wechat-spec-executor")
python $Validator (Join-Path $RepoRoot ".agents\skills\wechat-lab-builder")
```

## Default Behavior

- Generated projects are preview-first by default.
- `touristappid` projects stay blocked from upload and deploy.
- Real upload is only for explicit real-appid cases after guard checks.
- If real deploy config is missing, use `Invoke-WechatReleaseSetup` to collect local appid and private key settings on the user's machine.

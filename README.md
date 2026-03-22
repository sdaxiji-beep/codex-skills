# codex_skills

Codex skill workspace for building WeChat Mini Programs from natural language.

This is not a prompt library. It is a guarded local workflow for:
- creating a project shell from a prompt
- generating page-level code through a JSON bundle contract
- blocking invalid Mini Program code before it touches disk
- previewing generated projects while keeping real upload/deploy behind local release setup

## V1.1: Generation Gate Architecture

Standard AI coding flows often write raw files directly. This workspace does not.

It forces page-generation work through a structured JSON bundle and a local validation gate before any write is allowed.

```text
[Human Prompt]
      |
      v
[Invoke-WechatGeneratePage]
      |
      v
[PAGE_GENERATION_SPEC] ---> [Agent reads spec and writes JSON bundle]
                                      |
                                      v
                                [Generation Gate]
                                 /     |      \
                                /      |       \
                         Exit 0       Exit 1    Exit 2
                           |            |         |
                           v            v         v
                    [Write files]   [Fix bundle] [Abort]
                                         |
                                         +----> retry apply
```

## The 3 Tiers Of Guarantees

### Tier 0: Hard Repository Guarantee

Dirty code does not get written through the gated page-generation path.

If the model emits:
- HTML tags such as `<div>`
- Web APIs such as `fetch`, `axios`, `window`, or `document`
- out-of-sandbox paths such as `app.json` or `project.config.json`

the Generation Gate rejects the bundle before write.

### Tier 1: Autonomous Self-Repair In Supportive Clients

In clients that continue the tool-use loop after a retryable failure, exit code `1` plus stderr can drive an autonomous fix-and-retry cycle.

This behavior has been verified in the current Codex desktop environment used for this repo. Treat it as client-dependent behavior, not a universal guarantee across all agent products.

### Tier 2: Manual Fallback In Restricted Clients

If a client stops after exit code `1`, the workflow still holds:
- read stderr
- fix the exact reported bundle errors
- run the same apply command again

The hard guarantee from Tier 0 remains intact either way.

## Real Pressure Drill

A real pressure drill was completed against `pages/home/index` in a generated project.

The first bundle intentionally included:
- `<div>` in WXML
- `fetch(...)` in page logic

Result:
- `wechat-apply-bundle.ps1` rejected the bundle with exit code `1`
- stderr reported unauthorized HTML tags and forbidden Web request APIs
- the bundle was corrected to use `<view>` and `wx.request(...)`
- the next apply succeeded and wrote `.wxml`, `.js`, `.wxss`, and `.json`

This proves the guarded page-generation path works on a non-template page and that retryable failures can be repaired without allowing dirty writes.

## Requirements

- Windows
- PowerShell
- WeChat DevTools installed locally
- Codex desktop or another agent environment that can read local skill folders and execute local tools

## What Is Included

- `/.agents/skills/`
  - `wechat-devtools-control`
  - `wechat-release-guard`
  - `wechat-spec-executor`
  - `wechat-lab-builder`
  - `wechat-page-generator`
  - `wechat-component-generator`
  - `wechat-global-config-modifier`
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

`generated/` and `artifacts/` are runtime-only folders. They are ignored by Git and should not be published as release content.

## Quick Start

```powershell
cd <your-cloned-repo-path>
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")

# 1. Bootstrap and doctor
Invoke-WechatBootstrap
Invoke-WechatDoctor

# 2. Create a project shell
Invoke-WechatCreate -Prompt "build a notebook mini program" -Open $false -Preview $false

# 3. Create a page-generation task
Invoke-WechatGeneratePage -Prompt "Build a homepage with a swiper and a 2-column product list" -PagePath "pages/home/index"

# 4. Create an app.json patch task for the new page
Invoke-WechatPatchAppJson -Prompt "register the home page in app.json routes" -PagePaths "pages/home/index"
```

After step 3, use the `wechat-page-generator` skill to generate the JSON bundle, pass it through the Generation Gate, and write the validated page files.
After step 4, use the `wechat-global-config-modifier` skill to generate the append-only patch and merge the validated route into `app.json`.

## Install Options

### Option A: Use this repo as a full workspace

Recommended if you want the skills and the scripts/templates to work together immediately.

```powershell
cd <your-cloned-repo-path>
$RepoRoot = (Get-Location).Path
. (Join-Path $RepoRoot "scripts\wechat.ps1")
```

### Option B: Install only the skills into your own Codex skill directory

Use this only if you already have an equivalent local workspace with matching `scripts`, `templates`, `config`, and `mcp` paths.

Copy these folders into your Codex skills directory:
- `<repo-root>\.agents\skills\wechat-devtools-control`
- `<repo-root>\.agents\skills\wechat-release-guard`
- `<repo-root>\.agents\skills\wechat-spec-executor`
- `<repo-root>\.agents\skills\wechat-lab-builder`
- `<repo-root>\.agents\skills\wechat-page-generator`
- `<repo-root>\.agents\skills\wechat-component-generator`
- `<repo-root>\.agents\skills\wechat-global-config-modifier`

If you install only the skill folders but not the supporting workspace, the skills may load correctly but fail at runtime because the expected local scripts are missing.

## Recommended Usage

For normal use, do not memorize commands. Ask Codex in natural language, for example:
- "Help me create a notebook mini program and preview it."
- "Run a WeChat environment doctor check."
- "Generate pages/home/index from this requirement and keep it inside the page sandbox."
- "Register pages/about/index in app.json through the append_pages patch flow."

The commands remain available for debugging, documentation, or manual operation.

## Validate Skills

```powershell
# Default path (works if Codex installed to default location)
$Validator = Join-Path $env:USERPROFILE ".codex\skills\.system\skill-creator\scripts\quick_validate.py"

# If the default path does not exist, set it manually before running
if (-not (Test-Path $Validator)) {
  Write-Error "skill-creator not found at: $Validator"
  Write-Error "Set `$Validator to your local quick_validate.py path and re-run."
  return
}

$RepoRoot = (Get-Location).Path

python $Validator (Join-Path $RepoRoot ".agents\skills\wechat-devtools-control")
python $Validator (Join-Path $RepoRoot ".agents\skills\wechat-release-guard")
python $Validator (Join-Path $RepoRoot ".agents\skills\wechat-spec-executor")
python $Validator (Join-Path $RepoRoot ".agents\skills\wechat-lab-builder")
python $Validator (Join-Path $RepoRoot ".agents\skills\wechat-page-generator")
python $Validator (Join-Path $RepoRoot ".agents\skills\wechat-component-generator")
python $Validator (Join-Path $RepoRoot ".agents\skills\wechat-global-config-modifier")
```

## Validation

```powershell
$RepoRoot = (Get-Location).Path
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\test-wechat-skill.ps1") -GuardCheckOnly
```

## Default Behavior

- Generated projects are preview-first by default.
- `touristappid` projects stay blocked from upload and deploy.
- Real upload is only for explicit real-appid cases after guard checks.
- Page generation is confined to `pages/**` through the Generation Gate path.
- app.json global routing changes are confined to append-only `append_pages` patches.
- If real deploy config is missing, use `Invoke-WechatReleaseSetup` to collect local appid and private key settings on the user's machine.

## Runtime Hygiene

Use the cleanup helper before packaging or sharing screenshots/logs:

```powershell
$RepoRoot = (Get-Location).Path
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\cleanup-runtime-data.ps1")
# Apply cleanup
powershell -ExecutionPolicy Bypass -File (Join-Path $RepoRoot "scripts\cleanup-runtime-data.ps1") -Apply
```

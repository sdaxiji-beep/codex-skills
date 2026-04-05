[CmdletBinding()]
param()

. "$PSScriptRoot\wechat-get-port.ps1"
. "$PSScriptRoot\wechat-readonly-flow.ps1"
. "$PSScriptRoot\wechat-write-guard.ps1"
. "$PSScriptRoot\wechat-deploy.ps1"
. "$PSScriptRoot\wechat-open-project.ps1"
. "$PSScriptRoot\wechat-auto-fix.ps1"
. "$PSScriptRoot\wechat-agentic-loop.ps1"
. "$PSScriptRoot\wechat-task-product-routing.ps1"
. "$PSScriptRoot\wechat-task-spec.ps1"
. "$PSScriptRoot\wechat-task-bundle-compiler.ps1"
. "$PSScriptRoot\wechat-task-translator.ps1"
. "$PSScriptRoot\wechat-task-executor.ps1"
. "$PSScriptRoot\wechat-acceptance-checks.ps1"
. "$PSScriptRoot\wechat-acceptance-repair-loop.ps1"
. "$PSScriptRoot\wechat-task-dispatch.ps1"
. "$PSScriptRoot\wechat-generated-project.ps1"
. "$PSScriptRoot\wechat-create.ps1"
. "$PSScriptRoot\wechat-generate-page.ps1"
. "$PSScriptRoot\wechat-generate-component.ps1"
. "$PSScriptRoot\wechat-patch-app-json.ps1"
. "$PSScriptRoot\wechat-doctor.ps1"
. "$PSScriptRoot\wechat-env-recovery.ps1"
. "$PSScriptRoot\wechat-bootstrap.ps1"
. "$PSScriptRoot\get-diagnostics-metrics-summary.ps1"

function Invoke-WechatReadonlyCheck {
    [CmdletBinding()]
    param(
        [int]$Window = 20,
        [int]$KeepLast = 200,
        [switch]$AsJson
    )

    $scriptPath = Join-Path $PSScriptRoot 'mcp-readonly-check.ps1'
    if (-not (Test-Path $scriptPath)) {
        throw "Readonly check script not found: $scriptPath"
    }

    & $scriptPath -Window $Window -KeepLast $KeepLast -AsJson:$AsJson
}

function Invoke-WechatMcpSafetyCheck {
    [CmdletBinding()]
    param(
        [int]$Window = 20,
        [int]$KeepLast = 200,
        [switch]$AsJson
    )

    $scriptPath = Join-Path $PSScriptRoot 'mcp-safety-check.ps1'
    if (-not (Test-Path $scriptPath)) {
        throw "MCP safety check script not found: $scriptPath"
    }

    & $scriptPath -Window $Window -KeepLast $KeepLast -AsJson:$AsJson
}

function Get-WechatHelp {
    Write-Host @"
========================================
 WeChat DevTools Control - Available Commands
========================================

[Validation]
  Invoke-WechatBootstrap
  Invoke-WechatDoctor
  Get-WechatValidationPlan
  Get-WechatPublicApiSurface
  Get-DiagnosticsMetricsSummary
  Invoke-FlowViaAutomator
  Invoke-AgenticLoop
  Invoke-WechatReadonlyCheck
  Invoke-WechatMcpSafetyCheck

[Deploy]
  Invoke-WechatPreview
  Invoke-WechatUpload
  Invoke-PackNpm
  Invoke-DeployCloudFunction
  Invoke-DeployAllCloudFunctions
  Invoke-DeployChangedCloudFunctions

[Project]
  Invoke-WechatCreate
  Invoke-WechatGeneratePage
  Invoke-WechatGenerateComponent
  Invoke-WechatPatchAppJson
  Invoke-OpenProject
  Get-GeneratedProjectList
  Invoke-GeneratedProjectOpen
  Invoke-GeneratedProjectPreview
  Invoke-GeneratedProjectDeployGuard
  Invoke-GeneratedProjectSetAppId
  Invoke-GeneratedProjectUpload
  Note: generated projects are preview-first by default; upload is only for real appid + explicit intent
  Get-WechatDevtoolsPort
  Get-CloudFunctionList
  Get-CloudEnvList

[Spec Driven]
  Invoke-AgenticLoopFromSpec
  Invoke-WechatTask

[Task Dispatch]
  preview current project
  run layer 4 validation
  read-only cloud function diagnostic
  add log to getOrder        (confirmation required)
  add log to timerCancelOrder (confirmation required)
  Invoke-WechatTask -ResolveOnly "..."
  Invoke-WechatTask -SuggestOnly "..."
  Invoke-WechatTask -RecommendOnly "..."
  Invoke-WechatTask -HandoffOnly "..."
  Note: write routes are blocked by default unless -AllowWriteRoute is provided.

Use function name with -? to inspect parameters
========================================
"@
}

function Get-WechatValidationPlan {
    Write-Host @"
========================================
 WeChat Validation Plan
========================================

[L0 - Syntax / Guard]
  powershell -ExecutionPolicy Bypass -File .\scripts\test-wechat-skill.ps1 -GuardCheckOnly

[L1 - Diagnostics Focused]
  powershell -ExecutionPolicy Bypass -File .\scripts\test-diagnostics-focused.ps1

[L2 - Fast Core Regression]
  powershell -ExecutionPolicy Bypass -File .\scripts\test-wechat-skill.ps1 -SkipSmoke -Tag fast

[L3 - Full Integration Regression]
  powershell -ExecutionPolicy Bypass -File .\scripts\test-wechat-skill.ps1 -Tag full

Notes:
  - cached deploy/preview gate timing is not the same as full regression timing
  - run fast and full sequentially, not in parallel
  - see TEST_TIERS.md for detailed guidance and runtime expectations

========================================
"@
}

function Get-WechatPublicApiSurface {
    Write-Host @"
========================================
 WeChat Public API Surface
========================================

[Human/operator public entrypoint]
  scripts\wechat.ps1

[External client boundary]
  scripts\wechat-mcp-tool-boundary.ps1

[Diagnostics operator entrypoint]
  diagnostics\Invoke-RepairLoopAuto.ps1

[Public docs]
  README.md
  CLAUDE.md
  MCP_BOUNDARY_CONTRACT.md
  EXTERNAL_CLIENT_ENTRYPOINTS.md
  TEST_TIERS.md
  RUNTIME_RETENTION_POLICY.md
  RELEASE_PACKAGE.md
  PUBLIC_API_SURFACE.md

[Public skills]
  .agents\skills\wechat-devtools-control
  .agents\skills\wechat-release-guard
  .agents\skills\wechat-spec-executor
  .agents\skills\wechat-lab-builder

Notes:
  - test-* scripts are not public API
  - most generation-gate/apply scripts are internal implementation
  - see PUBLIC_API_SURFACE.md for the full classification

========================================
"@
}

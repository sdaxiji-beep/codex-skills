[CmdletBinding()]
param()

. "$PSScriptRoot\wechat-get-port.ps1"
. "$PSScriptRoot\wechat-readonly-flow.ps1"
. "$PSScriptRoot\wechat-write-guard.ps1"
. "$PSScriptRoot\wechat-deploy.ps1"
. "$PSScriptRoot\wechat-open-project.ps1"
. "$PSScriptRoot\wechat-auto-fix.ps1"
. "$PSScriptRoot\wechat-agentic-loop.ps1"
. "$PSScriptRoot\wechat-task-dispatch.ps1"
. "$PSScriptRoot\wechat-generated-project.ps1"
. "$PSScriptRoot\wechat-create.ps1"
. "$PSScriptRoot\wechat-generate-page.ps1"
. "$PSScriptRoot\wechat-generate-component.ps1"
. "$PSScriptRoot\wechat-patch-app-json.ps1"
. "$PSScriptRoot\wechat-doctor.ps1"
. "$PSScriptRoot\wechat-bootstrap.ps1"

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

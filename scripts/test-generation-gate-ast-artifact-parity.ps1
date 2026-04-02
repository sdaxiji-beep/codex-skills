param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-v1.ps1"
. "$PSScriptRoot\generation-gate-component-v1.ps1"

$oldHybrid = $env:WECHAT_AST_HYBRID_MODE
$oldPromoted = $env:WECHAT_AST_PROMOTED_SEVERITIES
$oldForceError = $env:WECHAT_AST_TEST_FORCE_ERROR
$oldForceWarn = $env:WECHAT_AST_TEST_FORCE_WARNING

try {
    Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue
    Remove-Item Env:WECHAT_AST_PROMOTED_SEVERITIES -ErrorAction SilentlyContinue
    Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue
    Remove-Item Env:WECHAT_AST_TEST_FORCE_WARNING -ErrorAction SilentlyContinue

    $pagePayload = @'
{
  "page_name": "about",
  "files": [
    { "path": "pages/about/index.wxml", "content": "<view><text>About</text></view>" },
    { "path": "pages/about/index.js", "content": "Page({ data: {}, onLoad() {} })" },
    { "path": "pages/about/index.wxss", "content": ".container { padding: 20rpx; }" },
    { "path": "pages/about/index.json", "content": "{ \"usingComponents\": {} }" }
  ]
}
'@
    $componentPayload = @'
{
  "component_name": "cta-button",
  "files": [
    { "path": "components/cta-button/index.wxml", "content": "<view><button>{{text}}</button></view>" },
    { "path": "components/cta-button/index.js", "content": "Component({ properties: { text: { type: String, value: 'Click' } }, data: {}, methods: {} })" },
    { "path": "components/cta-button/index.wxss", "content": ".wrap { padding: 20rpx; }" },
    { "path": "components/cta-button/index.json", "content": "{ \"component\": true, \"usingComponents\": {} }" }
  ]
}
'@

    $pageResult = Invoke-GenerationGateV1 -JsonPayload $pagePayload
    Assert-Equal $pageResult.Status 'pass' 'Page payload should pass for artifact parity test'
    $componentResult = Invoke-GenerationGateComponentV1 -JsonPayload $componentPayload
    Assert-Equal $componentResult.Status 'pass' 'Component payload should pass for artifact parity test'

    $artifactDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools\generation-gate'
    $pageArtifactPath = Join-Path $artifactDir 'ast-shadow-latest.json'
    $componentArtifactPath = Join-Path $artifactDir 'component-ast-shadow-latest.json'
    Assert-True (Test-Path $pageArtifactPath) 'Page AST artifact should exist'
    Assert-True (Test-Path $componentArtifactPath) 'Component AST artifact should exist'

    $pageArtifact = Get-Content $pageArtifactPath -Raw | ConvertFrom-Json
    $componentArtifact = Get-Content $componentArtifactPath -Raw | ConvertFrom-Json

    $requiredFields = @(
        'generated_at',
        'gate_status',
        'gate_error_count',
        'hybrid_mode',
        'promoted_severities',
        'shadow_executed',
        'shadow_available',
        'shadow_parser',
        'shadow_error_count',
        'promoted_error_count',
        'promoted_diagnostic_count',
        'shadow_error',
        'shadow_mismatch',
        'diagnostics'
    )

    foreach ($field in $requiredFields) {
        Assert-True ($pageArtifact.PSObject.Properties.Name -contains $field) "Page artifact missing field: $field"
        Assert-True ($componentArtifact.PSObject.Properties.Name -contains $field) "Component artifact missing field: $field"
    }

    Assert-True ($pageArtifact.promoted_diagnostic_count -ge $pageArtifact.promoted_error_count) 'Page promoted_diagnostic_count should be >= promoted_error_count'
    Assert-True ($componentArtifact.promoted_diagnostic_count -ge $componentArtifact.promoted_error_count) 'Component promoted_diagnostic_count should be >= promoted_error_count'
    Assert-Equal $pageArtifact.hybrid_mode $true 'Page artifact hybrid_mode should default to true'
    Assert-Equal $componentArtifact.hybrid_mode $true 'Component artifact hybrid_mode should default to true'
    Assert-Equal ($pageArtifact.promoted_severities -join ',') 'error' 'Page artifact default promoted_severities should be error'
    Assert-Equal ($componentArtifact.promoted_severities -join ',') 'error' 'Component artifact default promoted_severities should be error'

    New-TestResult -Name 'generation-gate-ast-artifact-parity' -Data @{
        pass = $true
        exit_code = 0
        page_promoted_severities = ($pageArtifact.promoted_severities -join ',')
        component_promoted_severities = ($componentArtifact.promoted_severities -join ',')
    }
}
finally {
    if ($null -eq $oldHybrid) { Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_HYBRID_MODE = $oldHybrid }
    if ($null -eq $oldPromoted) { Remove-Item Env:WECHAT_AST_PROMOTED_SEVERITIES -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_PROMOTED_SEVERITIES = $oldPromoted }
    if ($null -eq $oldForceError) { Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_TEST_FORCE_ERROR = $oldForceError }
    if ($null -eq $oldForceWarn) { Remove-Item Env:WECHAT_AST_TEST_FORCE_WARNING -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_TEST_FORCE_WARNING = $oldForceWarn }
}

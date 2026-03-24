param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-component-v1.ps1"

$oldHybrid = $env:WECHAT_AST_HYBRID_MODE
$oldForce = $env:WECHAT_AST_TEST_FORCE_ERROR
$artifactPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools\generation-gate\component-ast-shadow-latest.json'

try {
    $env:WECHAT_AST_TEST_FORCE_ERROR = '1'
    Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue

    $payload = @'
{
  "component_name": "cta-button",
  "files": [
    {
      "path": "components/cta-button/index.wxml",
      "content": "<view><button>{{text}}</button></view>"
    },
    {
      "path": "components/cta-button/index.js",
      "content": "Component({ properties: { text: { type: String, value: 'Click' } }, data: {}, methods: {} })"
    },
    {
      "path": "components/cta-button/index.wxss",
      "content": ".wrap { padding: 20rpx; }"
    },
    {
      "path": "components/cta-button/index.json",
      "content": "{ \"component\": true, \"usingComponents\": {} }"
    }
  ]
}
'@

    $defaultResult = Invoke-GenerationGateComponentV1 -JsonPayload $payload
    Assert-Equal $defaultResult.Status 'retryable_fail' 'Default hybrid mode should be ON and promote component AST errors'
    Assert-True (@($defaultResult.Errors | Where-Object { $_ -match '^AST Error \[' }).Count -gt 0) 'Default mode should emit component AST Error messages'

    Assert-True (Test-Path $artifactPath) 'Component AST shadow artifact should exist'
    $defaultArtifact = Get-Content $artifactPath -Raw | ConvertFrom-Json
    Assert-Equal $defaultArtifact.hybrid_mode $true 'Artifact should record hybrid mode ON by default'

    $env:WECHAT_AST_HYBRID_MODE = '0'
    $rollbackResult = Invoke-GenerationGateComponentV1 -JsonPayload $payload
    Assert-Equal $rollbackResult.Status 'pass' 'Rollback mode should disable AST promotion and keep valid component bundle passing'
    Assert-Equal (@($rollbackResult.Errors | Where-Object { $_ -match '^AST Error \[' }).Count) 0 'Rollback mode should not append component AST Error messages'

    $rollbackArtifact = Get-Content $artifactPath -Raw | ConvertFrom-Json
    Assert-Equal $rollbackArtifact.hybrid_mode $false 'Artifact should record hybrid mode OFF after rollback'

    New-TestResult -Name 'generation-gate-component-ast-hybrid-default-and-rollback' -Data @{
        pass = $true
        exit_code = 0
        default_mode = 'on'
        rollback_mode = 'off'
    }
}
finally {
    if ($null -eq $oldHybrid) { Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_HYBRID_MODE = $oldHybrid }
    if ($null -eq $oldForce) { Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_TEST_FORCE_ERROR = $oldForce }
}

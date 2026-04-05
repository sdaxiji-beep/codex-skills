param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-v1.ps1"

$oldHybrid = $env:WECHAT_AST_HYBRID_MODE
$oldForce = $env:WECHAT_AST_TEST_FORCE_ERROR
$artifactPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools\generation-gate\ast-shadow-latest.json'

try {
    $env:WECHAT_AST_TEST_FORCE_ERROR = '1'
    Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue

    $payload = @'
{
  "page_name": "about",
  "files": [
    {
      "path": "pages/about/index.wxml",
      "content": "<view><text>About</text></view>"
    },
    {
      "path": "pages/about/index.js",
      "content": "Page({ data: {}, onLoad() {} })"
    },
    {
      "path": "pages/about/index.wxss",
      "content": ".container { padding: 20rpx; }"
    },
    {
      "path": "pages/about/index.json",
      "content": "{ \"usingComponents\": {} }"
    }
  ]
}
'@

    $defaultResult = Invoke-GenerationGateV1 -JsonPayload $payload
    Assert-Equal $defaultResult.Status 'retryable_fail' 'Default hybrid mode should be ON and promote AST errors'
    Assert-True (@($defaultResult.Errors | Where-Object { $_ -match '^AST Error \[' }).Count -gt 0) 'Default mode should emit AST Error messages'

    Assert-True (Test-Path $artifactPath) 'AST shadow artifact should exist'
    $defaultArtifact = Get-Content $artifactPath -Raw | ConvertFrom-Json
    Assert-Equal $defaultArtifact.hybrid_mode $true 'Artifact should record hybrid mode ON by default'

    $env:WECHAT_AST_HYBRID_MODE = '0'
    $rollbackResult = Invoke-GenerationGateV1 -JsonPayload $payload
    Assert-Equal $rollbackResult.Status 'pass' 'Rollback mode should disable AST promotion and keep valid bundle passing'
    Assert-Equal (@($rollbackResult.Errors | Where-Object { $_ -match '^AST Error \[' }).Count) 0 'Rollback mode should not append AST Error messages'

    $rollbackArtifact = Get-Content $artifactPath -Raw | ConvertFrom-Json
    Assert-Equal $rollbackArtifact.hybrid_mode $false 'Artifact should record hybrid mode OFF after rollback'

    New-TestResult -Name 'generation-gate-ast-hybrid-default-and-rollback' -Data @{
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

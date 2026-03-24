param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-v1.ps1"

$oldHybrid = $env:WECHAT_AST_HYBRID_MODE
$oldForce = $env:WECHAT_AST_TEST_FORCE_ERROR
$env:WECHAT_AST_HYBRID_MODE = '1'
Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue

try {
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
      "content": "Page({ data: { foo: , }, onLoad() {} })"
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

    $result = Invoke-GenerationGateV1 -JsonPayload $payload
    Assert-Equal $result.Status 'retryable_fail' 'Hybrid parser mode should reject JS syntax errors'

    $astErrors = @($result.Errors | Where-Object { $_ -match '^AST Error \[js_parse_error\]' })
    Assert-True ($astErrors.Count -gt 0) 'Expected js_parse_error from AST parser'

    $artifactPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools\generation-gate\ast-shadow-latest.json'
    Assert-True (Test-Path $artifactPath) 'AST shadow artifact should exist'
    $artifact = Get-Content $artifactPath -Raw | ConvertFrom-Json
    Assert-Equal $artifact.hybrid_mode $true 'Artifact should record hybrid mode on'
    Assert-True ($artifact.promoted_error_count -ge 1) 'Artifact should report promoted AST errors'
    Assert-In $artifact.shadow_parser @('acorn','none') 'Artifact parser field should be present'

    New-TestResult -Name 'generation-gate-ast-hybrid-parser' -Data @{
        pass = $true
        exit_code = 0
        ast_error_count = $astErrors.Count
        shadow_parser = $artifact.shadow_parser
    }
}
finally {
    if ($null -eq $oldHybrid) { Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_HYBRID_MODE = $oldHybrid }
    if ($null -eq $oldForce) { Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_TEST_FORCE_ERROR = $oldForce }
}

param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-v1.ps1"

$oldHybrid = $env:WECHAT_AST_HYBRID_MODE
$oldForce = $env:WECHAT_AST_TEST_FORCE_ERROR
$env:WECHAT_AST_HYBRID_MODE = '1'
$env:WECHAT_AST_TEST_FORCE_ERROR = '1'

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

    $result = Invoke-GenerationGateV1 -JsonPayload $payload
    Assert-Equal $result.Status 'retryable_fail' 'Hybrid mode should promote AST errors to retryable_fail'
    $astError = @($result.Errors | Where-Object { $_ -match '^AST Error \[' })
    Assert-True ($astError.Count -gt 0) 'Hybrid mode should append AST Error messages'

    New-TestResult -Name 'generation-gate-ast-hybrid' -Data @{
        pass = $true
        exit_code = 0
        promoted_error_count = $astError.Count
    }
}
finally {
    if ($null -eq $oldHybrid) { Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_HYBRID_MODE = $oldHybrid }
    if ($null -eq $oldForce) { Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_TEST_FORCE_ERROR = $oldForce }
}

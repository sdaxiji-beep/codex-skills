param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-v1.ps1"

$oldHybrid = $env:WECHAT_AST_HYBRID_MODE
$oldForce = $env:WECHAT_AST_TEST_FORCE_ERROR
Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue
Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue

try {
    $payload = @'
{
  "page_name": "about",
  "files": [
    {
      "path": "pages/about/index.wxml",
      "content": "<view><text>About</view>"
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
    Assert-Equal $result.Status 'retryable_fail' 'Malformed WXML should fail under default hybrid mode'

    $astErrors = @($result.Errors | Where-Object {
        $_ -match '^AST Error \[(wxml_tag_mismatch|wxml_unclosed_tag|wxml_unmatched_close_tag)\]'
    })
    Assert-True ($astErrors.Count -gt 0) 'Expected AST WXML structure error diagnostics'

    New-TestResult -Name 'generation-gate-ast-wxml-semantics' -Data @{
        pass = $true
        exit_code = 0
        ast_error_count = $astErrors.Count
    }
}
finally {
    if ($null -eq $oldHybrid) { Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_HYBRID_MODE = $oldHybrid }
    if ($null -eq $oldForce) { Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_TEST_FORCE_ERROR = $oldForce }
}

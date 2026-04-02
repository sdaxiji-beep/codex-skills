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
      "content": "<view wx:for=\"{{list}}\"><text wx:if=\"{{ok}}\" wx:else=\"true\">row</text></view>"
    },
    {
      "path": "pages/about/index.js",
      "content": "Page({ data: { list: [1,2], ok: true }, onLoad() {} })"
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
    Assert-Equal $result.Status 'retryable_fail' 'WXML directive semantic violations should fail under default hybrid mode'

    $forKeyErr = @($result.Errors | Where-Object { $_ -match '^AST Error \[wxml_wx_for_missing_key\]' })
    $elseValueErr = @($result.Errors | Where-Object { $_ -match '^AST Error \[wxml_wx_else_has_value\]' })
    $conflictErr = @($result.Errors | Where-Object { $_ -match '^AST Error \[wxml_conditional_conflict\]' })
    Assert-True ($forKeyErr.Count -gt 0) 'Expected wxml_wx_for_missing_key AST error'
    Assert-True ($elseValueErr.Count -gt 0) 'Expected wxml_wx_else_has_value AST error'
    Assert-True ($conflictErr.Count -gt 0) 'Expected wxml_conditional_conflict AST error'

    New-TestResult -Name 'generation-gate-ast-wxml-directive-semantics' -Data @{
        pass = $true
        exit_code = 0
        for_key_error_count = $forKeyErr.Count
        else_value_error_count = $elseValueErr.Count
        conflict_error_count = $conflictErr.Count
    }
}
finally {
    if ($null -eq $oldHybrid) { Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_HYBRID_MODE = $oldHybrid }
    if ($null -eq $oldForce) { Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_TEST_FORCE_ERROR = $oldForce }
}

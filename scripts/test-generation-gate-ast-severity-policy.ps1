param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-v1.ps1"

$oldHybrid = $env:WECHAT_AST_HYBRID_MODE
$oldForceError = $env:WECHAT_AST_TEST_FORCE_ERROR
$oldForceWarn = $env:WECHAT_AST_TEST_FORCE_WARNING
$oldPromoted = $env:WECHAT_AST_PROMOTED_SEVERITIES

try {
    $env:WECHAT_AST_HYBRID_MODE = '1'
    Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue
    $env:WECHAT_AST_TEST_FORCE_WARNING = '1'

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

    Remove-Item Env:WECHAT_AST_PROMOTED_SEVERITIES -ErrorAction SilentlyContinue
    $defaultResult = Invoke-GenerationGateV1 -JsonPayload $payload
    Assert-Equal $defaultResult.Status 'pass' 'Default severity policy should not promote warn diagnostics'
    $defaultWarnPromoted = @($defaultResult.Errors | Where-Object { $_ -match '^AST Warn \[' }).Count
    Assert-Equal $defaultWarnPromoted 0 'Default severity policy should not append AST Warn messages'

    $env:WECHAT_AST_PROMOTED_SEVERITIES = 'error,warn'
    $warnPromotedResult = Invoke-GenerationGateV1 -JsonPayload $payload
    Assert-Equal $warnPromotedResult.Status 'retryable_fail' 'Configured severity policy should promote warn diagnostics'
    $warnPromoted = @($warnPromotedResult.Errors | Where-Object { $_ -match '^AST Warn \[forced_ast_warning\]' }).Count
    Assert-True ($warnPromoted -gt 0) 'Configured severity policy should append AST Warn messages'

    New-TestResult -Name 'generation-gate-ast-severity-policy' -Data @{
        pass = $true
        exit_code = 0
        default_status = $defaultResult.Status
        configured_status = $warnPromotedResult.Status
        configured_warn_promoted_count = $warnPromoted
    }
}
finally {
    if ($null -eq $oldHybrid) { Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_HYBRID_MODE = $oldHybrid }
    if ($null -eq $oldForceError) { Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_TEST_FORCE_ERROR = $oldForceError }
    if ($null -eq $oldForceWarn) { Remove-Item Env:WECHAT_AST_TEST_FORCE_WARNING -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_TEST_FORCE_WARNING = $oldForceWarn }
    if ($null -eq $oldPromoted) { Remove-Item Env:WECHAT_AST_PROMOTED_SEVERITIES -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_PROMOTED_SEVERITIES = $oldPromoted }
}

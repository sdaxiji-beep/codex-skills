param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-component-v1.ps1"

$oldHybrid = $env:WECHAT_AST_HYBRID_MODE
$oldForce = $env:WECHAT_AST_TEST_FORCE_ERROR
$env:WECHAT_AST_HYBRID_MODE = '1'
$env:WECHAT_AST_TEST_FORCE_ERROR = '1'

try {
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

    $result = Invoke-GenerationGateComponentV1 -JsonPayload $payload
    Assert-Equal $result.Status 'retryable_fail' 'Hybrid mode should promote AST errors to retryable_fail on component gate'
    $astError = @($result.Errors | Where-Object { $_ -match '^AST Error \[' })
    Assert-True ($astError.Count -gt 0) 'Hybrid mode should append component AST Error messages'

    New-TestResult -Name 'generation-gate-component-ast-hybrid' -Data @{
        pass = $true
        exit_code = 0
        promoted_error_count = $astError.Count
    }
}
finally {
    if ($null -eq $oldHybrid) { Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_HYBRID_MODE = $oldHybrid }
    if ($null -eq $oldForce) { Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_TEST_FORCE_ERROR = $oldForce }
}

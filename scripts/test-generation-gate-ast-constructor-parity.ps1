param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\generation-gate-v1.ps1"
. "$PSScriptRoot\generation-gate-component-v1.ps1"

$oldHybrid = $env:WECHAT_AST_HYBRID_MODE
$oldForce = $env:WECHAT_AST_TEST_FORCE_ERROR
Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue
Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue

try {
    $pagePayload = @'
{
  "page_name": "about",
  "files": [
    {
      "path": "pages/about/index.wxml",
      "content": "<view><text>About</text></view>"
    },
    {
      "path": "pages/about/index.js",
      "content": "Component({ properties: {}, data: {}, methods: {} })"
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

    $pageResult = Invoke-GenerationGateV1 -JsonPayload $pagePayload
    Assert-Equal $pageResult.Status 'retryable_fail' 'Page constructor parity violation should fail under default hybrid mode'
    $pageAstErrors = @($pageResult.Errors | Where-Object { $_ -match '^AST Error \[js_constructor_mismatch_page\]' })
    Assert-True ($pageAstErrors.Count -gt 0) 'Expected AST constructor mismatch diagnostic for page path'

    $componentPayload = @'
{
  "component_name": "cta-button",
  "files": [
    {
      "path": "components/cta-button/index.wxml",
      "content": "<view><button>{{text}}</button></view>"
    },
    {
      "path": "components/cta-button/index.js",
      "content": "Page({ data: {}, onLoad() {} })"
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

    $componentResult = Invoke-GenerationGateComponentV1 -JsonPayload $componentPayload
    Assert-Equal $componentResult.Status 'retryable_fail' 'Component constructor parity violation should fail under default hybrid mode'
    $componentAstErrors = @($componentResult.Errors | Where-Object { $_ -match '^AST Error \[js_constructor_mismatch_component\]' })
    Assert-True ($componentAstErrors.Count -gt 0) 'Expected AST constructor mismatch diagnostic for component path'

    New-TestResult -Name 'generation-gate-ast-constructor-parity' -Data @{
        pass = $true
        exit_code = 0
        page_ast_error_count = $pageAstErrors.Count
        component_ast_error_count = $componentAstErrors.Count
    }
}
finally {
    if ($null -eq $oldHybrid) { Remove-Item Env:WECHAT_AST_HYBRID_MODE -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_HYBRID_MODE = $oldHybrid }
    if ($null -eq $oldForce) { Remove-Item Env:WECHAT_AST_TEST_FORCE_ERROR -ErrorAction SilentlyContinue } else { $env:WECHAT_AST_TEST_FORCE_ERROR = $oldForce }
}

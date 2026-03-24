param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$scriptPath = Join-Path $PSScriptRoot 'wechat-mcp-tool-boundary.ps1'
Assert-True (Test-Path $scriptPath) 'wechat-mcp-tool-boundary.ps1 should exist'

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

$patchPayload = @'
{
  "append_pages": ["pages/about/index"]
}
'@

$workspace = Join-Path ([System.IO.Path]::GetTempPath()) ("mcp-boundary-contract-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $workspace -Force | Out-Null

try {
    $validatePage = & $scriptPath -Operation validate_page_bundle -JsonPayload $pagePayload -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $validatePage.status 'success' 'validate_page_bundle should return success envelope'
    Assert-Equal $validatePage.gate_status 'pass' 'validate_page_bundle should pass for valid payload'

    $validateComponent = & $scriptPath -Operation validate_component_bundle -JsonPayload $componentPayload -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $validateComponent.status 'success' 'validate_component_bundle should return success envelope'
    Assert-Equal $validateComponent.gate_status 'pass' 'validate_component_bundle should pass for valid payload'

    $applyPage = & $scriptPath -Operation apply_page_bundle -JsonPayload $pagePayload -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $applyPage.status 'success' 'apply_page_bundle should succeed for valid payload'

    $applyComponent = & $scriptPath -Operation apply_component_bundle -JsonPayload $componentPayload -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $applyComponent.status 'success' 'apply_component_bundle should succeed for valid payload'

    $appJsonPath = Join-Path $workspace 'app.json'
    Set-Content -Path $appJsonPath -Encoding UTF8 -Value (@{
        pages = @()
        window = @{ navigationBarTitleText = 'Test' }
    } | ConvertTo-Json -Depth 10)

    $validatePatch = & $scriptPath -Operation validate_app_json_patch -JsonPayload $patchPayload -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $validatePatch.status 'success' 'validate_app_json_patch should return success envelope'
    Assert-Equal $validatePatch.gate_status 'pass' 'validate_app_json_patch should pass for existing page'

    $applyPatch = & $scriptPath -Operation apply_app_json_patch -JsonPayload $patchPayload -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $applyPatch.status 'success' 'apply_app_json_patch should succeed for valid patch'

    New-TestResult -Name 'wechat-mcp-tool-boundary-contract' -Data @{
        pass = $true
        exit_code = 0
        workspace = $workspace
    }
}
finally {
    if (Test-Path $workspace) {
        Remove-Item -Path $workspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}

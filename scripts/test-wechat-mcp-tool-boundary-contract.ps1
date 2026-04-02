param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

if ($null -eq $Context) {
    $Context = @{}
}

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

$workspace = $null
$cleanupWorkspace = $false
$hasSharedContext = $null -ne $Context
$reuseWorkspace = $Context.ContainsKey('McpBoundaryValidWorkspace') -and (Test-Path $Context.McpBoundaryValidWorkspace)

if ($reuseWorkspace) {
    $workspace = $Context.McpBoundaryValidWorkspace
}
else {
    $workspace = Join-Path ([System.IO.Path]::GetTempPath()) ("mcp-boundary-contract-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $workspace -Force | Out-Null
    if ($hasSharedContext) {
        $Context.McpBoundaryValidWorkspace = $workspace
        $Context.McpBoundaryValidPagePayload = $pagePayload
        $Context.McpBoundaryValidComponentPayload = $componentPayload
        $Context.McpBoundaryValidPatchPayload = $patchPayload
    }
    else {
        $cleanupWorkspace = $true
    }
}

try {
    $cachedBoundaryContracts = if ($hasSharedContext -and $Context.ContainsKey('McpBoundaryContracts')) { $Context.McpBoundaryContracts } else { $null }

    if ($hasSharedContext) {
        $payloadPath = Join-Path $workspace 'page-bundle.json'
        if ((-not $Context.ContainsKey('McpBoundaryValidPayloadPath')) -or -not (Test-Path $Context.McpBoundaryValidPayloadPath)) {
            [System.IO.File]::WriteAllText($payloadPath, $pagePayload, (New-Object System.Text.UTF8Encoding($false)))
            $Context.McpBoundaryValidPayloadPath = $payloadPath
        }
    }

    $validatePage = if ($null -ne $cachedBoundaryContracts) { $cachedBoundaryContracts.page_validate } else { & $scriptPath -Operation validate_page_bundle -JsonPayload $pagePayload -TargetWorkspace $workspace | ConvertFrom-Json }
    Assert-Equal $validatePage.status 'success' 'validate_page_bundle should return success envelope'
    Assert-Equal $validatePage.gate_status 'pass' 'validate_page_bundle should pass for valid payload'

    $validateComponent = if ($null -ne $cachedBoundaryContracts) { $cachedBoundaryContracts.component_validate } else { & $scriptPath -Operation validate_component_bundle -JsonPayload $componentPayload -TargetWorkspace $workspace | ConvertFrom-Json }
    Assert-Equal $validateComponent.status 'success' 'validate_component_bundle should return success envelope'
    Assert-Equal $validateComponent.gate_status 'pass' 'validate_component_bundle should pass for valid payload'

    $applyPage = if ($null -ne $cachedBoundaryContracts) { $cachedBoundaryContracts.page_apply } else { & $scriptPath -Operation apply_page_bundle -JsonPayload $pagePayload -TargetWorkspace $workspace | ConvertFrom-Json }
    Assert-Equal $applyPage.status 'success' 'apply_page_bundle should succeed for valid payload'

    $applyComponent = if ($null -ne $cachedBoundaryContracts) { $cachedBoundaryContracts.component_apply } else { & $scriptPath -Operation apply_component_bundle -JsonPayload $componentPayload -TargetWorkspace $workspace | ConvertFrom-Json }
    Assert-Equal $applyComponent.status 'success' 'apply_component_bundle should succeed for valid payload'

    $appJsonPath = Join-Path $workspace 'app.json'
    Set-Content -Path $appJsonPath -Encoding UTF8 -Value (@{
        pages = @()
        window = @{ navigationBarTitleText = 'Test' }
    } | ConvertTo-Json -Depth 10)

    $validatePatch = if ($null -ne $cachedBoundaryContracts) { $cachedBoundaryContracts.patch_validate } else { & $scriptPath -Operation validate_app_json_patch -JsonPayload $patchPayload -TargetWorkspace $workspace | ConvertFrom-Json }
    Assert-Equal $validatePatch.status 'success' 'validate_app_json_patch should return success envelope'
    Assert-Equal $validatePatch.gate_status 'pass' 'validate_app_json_patch should pass for existing page'

    $applyPatch = if ($null -ne $cachedBoundaryContracts) { $cachedBoundaryContracts.patch_apply } else { & $scriptPath -Operation apply_app_json_patch -JsonPayload $patchPayload -TargetWorkspace $workspace | ConvertFrom-Json }
    Assert-Equal $applyPatch.status 'success' 'apply_app_json_patch should succeed for valid patch'

    New-TestResult -Name 'wechat-mcp-tool-boundary-contract' -Data @{
        pass = $true
        exit_code = 0
        workspace = $workspace
    }
}
finally {
    if ($cleanupWorkspace -and (Test-Path $workspace)) {
        Remove-Item -Path $workspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}

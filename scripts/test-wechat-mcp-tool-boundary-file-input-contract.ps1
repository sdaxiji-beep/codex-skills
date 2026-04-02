param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

if ($null -eq $Context) {
    $Context = @{}
}

$scriptPath = Join-Path $PSScriptRoot 'wechat-mcp-tool-boundary.ps1'
Assert-True (Test-Path $scriptPath) 'wechat-mcp-tool-boundary.ps1 should exist'

$workspace = $null
$payloadPath = $null
$cleanupWorkspace = $false
$hasSharedContext = $null -ne $Context
$reuseFixture = (
    $Context.ContainsKey('McpBoundaryValidWorkspace') -and
    $Context.ContainsKey('McpBoundaryValidPayloadPath') -and
    (Test-Path $Context.McpBoundaryValidWorkspace) -and
    (Test-Path $Context.McpBoundaryValidPayloadPath)
)

try {
    $cachedBoundaryContracts = if ($hasSharedContext -and $Context.ContainsKey('McpBoundaryContracts')) { $Context.McpBoundaryContracts } else { $null }

    if ($reuseFixture) {
        $workspace = $Context.McpBoundaryValidWorkspace
        $payloadPath = $Context.McpBoundaryValidPayloadPath
    }
    else {
        $workspace = Join-Path ([System.IO.Path]::GetTempPath()) ("mcp-boundary-file-input-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $workspace -Force | Out-Null
        $payloadPath = Join-Path $workspace 'page-bundle.json'
        @'
{
  "page_name": "about",
  "files": [
    { "path": "pages/about/index.wxml", "content": "<view><text>About</text></view>" },
    { "path": "pages/about/index.js", "content": "Page({ data: {}, onLoad() {} })" },
    { "path": "pages/about/index.wxss", "content": ".container { padding: 20rpx; }" },
    { "path": "pages/about/index.json", "content": "{ \"usingComponents\": {} }" }
  ]
}
'@ | Set-Content -Path $payloadPath -Encoding UTF8
        if ($hasSharedContext) {
            $Context.McpBoundaryValidWorkspace = $workspace
            $Context.McpBoundaryValidPayloadPath = $payloadPath
        }
        else {
            $cleanupWorkspace = $true
        }
    }

    $validate = if ($null -ne $cachedBoundaryContracts) { $cachedBoundaryContracts.file_input_validate } else { & $scriptPath -Operation validate_page_bundle -JsonFilePath $payloadPath -TargetWorkspace $workspace | ConvertFrom-Json }
    Assert-Equal $validate.status 'success' 'validate_page_bundle should support JsonFilePath input'
    Assert-Equal $validate.gate_status 'pass' 'validate_page_bundle from file should pass'

    $apply = if ($null -ne $cachedBoundaryContracts) { $cachedBoundaryContracts.file_input_apply } else { & $scriptPath -Operation apply_page_bundle -JsonFilePath $payloadPath -TargetWorkspace $workspace | ConvertFrom-Json }
    Assert-Equal $apply.status 'success' 'apply_page_bundle should support JsonFilePath input'
    Assert-Equal $apply.gate_status 'pass' 'apply_page_bundle from file should return pass gate_status'

    $writtenJs = Join-Path $workspace 'pages\about\index.js'
    Assert-True (Test-Path $writtenJs) 'apply_page_bundle from file should write target files'

    New-TestResult -Name 'wechat-mcp-tool-boundary-file-input-contract' -Data @{
        pass = $true
        exit_code = 0
        payload_path = $payloadPath
    }
}
finally {
    if ($cleanupWorkspace -and (Test-Path $workspace)) {
        Remove-Item -Path $workspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}

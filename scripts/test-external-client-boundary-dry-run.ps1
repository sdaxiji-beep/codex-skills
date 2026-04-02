param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

if ($null -eq $Context) {
    $Context = @{}
}

$boundaryScript = Join-Path $PSScriptRoot 'wechat-mcp-tool-boundary.ps1'
Assert-True (Test-Path $boundaryScript) 'wechat-mcp-tool-boundary.ps1 should exist'

$workspace = $null
$bundlePath = $null
$cleanupWorkspace = $false
$hasSharedContext = $null -ne $Context
$reuseFixture = (
    $Context.ContainsKey('ExternalClientDryRunWorkspace') -and
    $Context.ContainsKey('ExternalClientDryRunPayloadPath') -and
    (Test-Path $Context.ExternalClientDryRunWorkspace) -and
    (Test-Path $Context.ExternalClientDryRunPayloadPath)
)

$pagePayload = @'
{
  "page_name": "home",
  "files": [
    { "path": "pages/home/index.wxml", "content": "<view class=\"container\"><text>Home</text></view>" },
    { "path": "pages/home/index.js", "content": "Page({ data: {}, onLoad() {} })" },
    { "path": "pages/home/index.wxss", "content": ".container { padding: 24rpx; }" },
    { "path": "pages/home/index.json", "content": "{ \"usingComponents\": {} }" }
  ]
}
'@

try {
    $cachedBoundaryContracts = if ($hasSharedContext -and $Context.ContainsKey('McpBoundaryContracts')) { $Context.McpBoundaryContracts } else { $null }

    if ($reuseFixture) {
        $workspace = $Context.ExternalClientDryRunWorkspace
        $bundlePath = $Context.ExternalClientDryRunPayloadPath
    }
    else {
        $workspace = Join-Path ([System.IO.Path]::GetTempPath()) ("external-client-dry-run-" + [guid]::NewGuid().ToString('N'))
        $tasksDir = Join-Path $workspace '.agents\tasks'
        $bundlePath = Join-Path $tasksDir 'bundle_page_home.json'
        New-Item -ItemType Directory -Path $tasksDir -Force | Out-Null
        [System.IO.File]::WriteAllText($bundlePath, $pagePayload, (New-Object System.Text.UTF8Encoding($false)))
        if ($hasSharedContext) {
            $Context.ExternalClientDryRunWorkspace = $workspace
            $Context.ExternalClientDryRunPayloadPath = $bundlePath
        }
        else {
            $cleanupWorkspace = $true
        }
    }

    if ($Context.ContainsKey('McpBoundaryDescribeContract')) {
        $contract = $Context.McpBoundaryDescribeContract
    }
    else {
        $contract = & $boundaryScript -Operation describe_contract | ConvertFrom-Json
        $Context.McpBoundaryDescribeContract = $contract
    }
    Assert-Equal $contract.status 'success' 'describe_contract should succeed in external dry-run'

    if ($Context.ContainsKey('McpBoundaryExecutionProfile')) {
        $profile = $Context.McpBoundaryExecutionProfile
    }
    else {
        $profile = & $boundaryScript -Operation describe_execution_profile | ConvertFrom-Json
        $Context.McpBoundaryExecutionProfile = $profile
    }
    Assert-Equal $profile.status 'success' 'describe_execution_profile should succeed in external dry-run'

    $validate = if ($null -ne $cachedBoundaryContracts) { $cachedBoundaryContracts.external_validate } else { & $boundaryScript -Operation validate_page_bundle -JsonFilePath $bundlePath -TargetWorkspace $workspace | ConvertFrom-Json }
    Assert-Equal $validate.status 'success' 'validate_page_bundle should succeed in external dry-run'
    Assert-Equal $validate.gate_status 'pass' 'validate_page_bundle should pass in external dry-run'

    $apply = if ($null -ne $cachedBoundaryContracts) { $cachedBoundaryContracts.external_apply } else { & $boundaryScript -Operation apply_page_bundle -JsonFilePath $bundlePath -TargetWorkspace $workspace | ConvertFrom-Json }
    Assert-Equal $apply.status 'success' 'apply_page_bundle should succeed in external dry-run'
    Assert-Equal $apply.gate_status 'pass' 'apply_page_bundle should return pass gate status'

    Assert-True (Test-Path (Join-Path $workspace 'pages\home\index.wxml')) 'external dry-run should write WXML file'
    Assert-True (Test-Path (Join-Path $workspace 'pages\home\index.js')) 'external dry-run should write JS file'

    New-TestResult -Name 'external-client-boundary-dry-run' -Data @{
        pass = $true
        exit_code = 0
        interface_version = $profile.interface_version
        workspace = $workspace
    }
}
finally {
    if ($cleanupWorkspace -and (Test-Path $workspace)) {
        Remove-Item -Path $workspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}

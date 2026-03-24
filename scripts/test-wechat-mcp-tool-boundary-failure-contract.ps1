param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$scriptPath = Join-Path $PSScriptRoot 'wechat-mcp-tool-boundary.ps1'
Assert-True (Test-Path $scriptPath) 'wechat-mcp-tool-boundary.ps1 should exist'

$describe = & $scriptPath -Operation describe_contract | ConvertFrom-Json
Assert-Equal $describe.status 'success' 'describe_contract should succeed'
Assert-Equal $describe.interface_version 'mcp_tool_boundary_v1' 'describe_contract should expose interface version'
Assert-True (@($describe.supported_operations).Count -ge 7) 'describe_contract should expose supported operations'

$invalidPagePayload = @'
{
  "page_name": "about",
  "files": [
    { "path": "pages/about/index.wxml", "content": "<div>bad</div>" },
    { "path": "pages/about/index.js", "content": "Page({ data: {}, onLoad() {} })" },
    { "path": "pages/about/index.wxss", "content": ".container { padding: 20rpx; }" },
    { "path": "pages/about/index.json", "content": "{ \"usingComponents\": {} }" }
  ]
}
'@

$workspace = Join-Path ([System.IO.Path]::GetTempPath()) ("mcp-boundary-failure-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $workspace -Force | Out-Null

try {
    $validate = & $scriptPath -Operation validate_page_bundle -JsonPayload $invalidPagePayload -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $validate.status 'success' 'validate_page_bundle should return envelope even when gate fails'
    Assert-Equal $validate.gate_status 'retryable_fail' 'validate_page_bundle should report retryable_fail for invalid payload'
    Assert-Equal $validate.interface_version 'mcp_tool_boundary_v1' 'validate result should include interface version'

    $apply = & $scriptPath -Operation apply_page_bundle -JsonPayload $invalidPagePayload -TargetWorkspace $workspace | ConvertFrom-Json
    Assert-Equal $apply.status 'failed' 'apply_page_bundle should fail for invalid payload'
    Assert-Equal $apply.exit_code 1 'apply_page_bundle should map retryable failures to exit_code=1'
    Assert-Equal $apply.gate_status 'retryable_fail' 'apply_page_bundle should expose mapped gate_status'
    Assert-Equal $apply.interface_version 'mcp_tool_boundary_v1' 'apply result should include interface version'

    New-TestResult -Name 'wechat-mcp-tool-boundary-failure-contract' -Data @{
        pass = $true
        exit_code = 0
        validate_gate_status = $validate.gate_status
        apply_gate_status = $apply.gate_status
        apply_exit_code = $apply.exit_code
    }
}
finally {
    if (Test-Path $workspace) {
        Remove-Item -Path $workspace -Recurse -Force -ErrorAction SilentlyContinue
    }
}

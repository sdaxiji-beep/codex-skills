param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$scriptPath = Join-Path $PSScriptRoot 'wechat-mcp-tool-boundary.ps1'
Assert-True (Test-Path $scriptPath) 'wechat-mcp-tool-boundary.ps1 should exist'

$output = & $scriptPath -Operation validate_page_bundle
$exitCode = $LASTEXITCODE

$result = $output | ConvertFrom-Json
Assert-Equal $exitCode 1 'Boundary should exit with code 1 for missing payload'
Assert-Equal $result.status 'error' 'Boundary should return error status for missing payload'
Assert-Equal $result.operation 'validate_page_bundle' 'Boundary should keep operation name in error response'
Assert-Equal $result.interface_version 'mcp_tool_boundary_v1' 'Boundary should keep interface version in error response'
Assert-True ($result.message -match 'JsonPayload or JsonFilePath is required') 'Boundary error should explain missing payload contract'

New-TestResult -Name 'wechat-mcp-tool-boundary-error-contract' -Data @{
    pass = $true
    exit_code = 0
    boundary_exit_code = $exitCode
}

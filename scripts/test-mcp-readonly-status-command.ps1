param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$scriptPath = Join-Path $PSScriptRoot 'mcp-readonly-status.ps1'
Assert-True (Test-Path $scriptPath) 'mcp-readonly-status.ps1 should exist'

$jsonOut = & $scriptPath -AsJson 2>&1 | Out-String
Assert-NotEmpty $jsonOut 'mcp-readonly-status command should return JSON output'

$payload = $jsonOut | ConvertFrom-Json
Assert-True ($payload.readonly_mcp.stable -eq $true) 'readonly_mcp.stable should be true'
Assert-True ($payload.readonly_mcp.health.cloud_function_count -ge 1) 'cloud function count should be >= 1'
Assert-True ($payload.readonly_mcp.health.cloud_list_exit_code -eq 0) 'cloud-list exit code should be 0'

New-TestResult -Name 'mcp-readonly-status-command' -Data @{
    pass = $true
    exit_code = 0
    cloud_function_count = $payload.readonly_mcp.health.cloud_function_count
}

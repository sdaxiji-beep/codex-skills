param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$checkScript = Join-Path $PSScriptRoot 'mcp-readonly-check.ps1'
Assert-True (Test-Path $checkScript) 'mcp-readonly-check.ps1 should exist'

$raw = & $checkScript -AsJson -Window 20 -KeepLast 200 2>&1 | Out-String
Assert-NotEmpty $raw 'mcp-readonly-check should return JSON output'

$result = $raw | ConvertFrom-Json
Assert-True ($result.stable -eq $true) 'readonly check should be stable'
Assert-True ($result.errors.Count -eq 0) 'readonly check should have no errors'
Assert-True ($result.status.readonly_mcp.health.cloud_list_exit_code -eq 0) 'cloud-list exit code should be 0'
Assert-True ($result.status.readonly_mcp.health.cloud_function_count -ge 1) 'cloud function count should be >=1'
Assert-True ($result.trend.total_in_window -ge 1) 'trend window should have data'

New-TestResult -Name 'mcp-readonly-check' -Data @{
    pass = $true
    exit_code = 0
    cloud_function_count = $result.status.readonly_mcp.health.cloud_function_count
    trend_total = $result.trend.total_in_window
}

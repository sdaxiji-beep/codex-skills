param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$historyCommand = Join-Path $PSScriptRoot 'mcp-readonly-status-history.ps1'
$trendCommand = Join-Path $PSScriptRoot 'mcp-readonly-trend.ps1'

Assert-True (Test-Path $trendCommand) 'mcp-readonly-trend.ps1 should exist'
Assert-True (Test-Path $historyCommand) 'mcp-readonly-status-history.ps1 should exist'

# Ensure at least one fresh point exists in history before trend calculation.
& $historyCommand -KeepLast 200 | Out-Null

$trendOut = & $trendCommand -Window 20 -AsJson 2>&1 | Out-String
Assert-NotEmpty $trendOut 'mcp-readonly-trend should return JSON output'

$trend = $trendOut | ConvertFrom-Json
Assert-True ($trend.total_in_window -ge 1) 'trend total_in_window should be >= 1'
Assert-True ($trend.stable_count -ge 1) 'trend stable_count should be >= 1'
Assert-True ($trend.cloud_list_healthy_count -ge 1) 'cloud_list_healthy_count should be >= 1'
Assert-True ($trend.probe_known_exit_count -ge 1) 'probe_known_exit_count should be >= 1'
Assert-True ($trend.max_probe_duration_ms -ge 0) 'max_probe_duration_ms should be >= 0'
Assert-True ($trend.max_cloud_list_duration_ms -ge 0) 'max_cloud_list_duration_ms should be >= 0'
Assert-True ($trend.last_snapshot.stable -eq $true) 'last snapshot should be stable'

New-TestResult -Name 'mcp-readonly-trend' -Data @{
    pass = $true
    exit_code = 0
    total_in_window = $trend.total_in_window
    stable_count = $trend.stable_count
}

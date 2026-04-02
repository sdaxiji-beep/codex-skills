param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$artifactsRoot = Join-Path $repoRoot 'artifacts'
$latestHealthPath = Join-Path $artifactsRoot 'mcp-readonly-health-latest.json'
$baselineHealthPath = Join-Path $artifactsRoot 'mcp-readonly-health-baseline.json'
$baselineComparePath = Join-Path $artifactsRoot 'mcp-readonly-baseline-latest.json'
$statusPath = Join-Path $artifactsRoot 'mcp-readonly-status-latest.json'

Assert-True (Test-Path $latestHealthPath) 'latest readonly health report should exist'
Assert-True (Test-Path $baselineHealthPath) 'baseline readonly health report should exist'
Assert-True (Test-Path $baselineComparePath) 'baseline comparison report should exist'

$latest = Get-Content $latestHealthPath -Raw | ConvertFrom-Json
$baseline = Get-Content $baselineHealthPath -Raw | ConvertFrom-Json
$compare = Get-Content $baselineComparePath -Raw | ConvertFrom-Json

Assert-True ($latest.cloud_list_exit_code -eq 0) 'latest cloud-list should be healthy'
Assert-True ($baseline.cloud_list_exit_code -eq 0) 'baseline cloud-list should be healthy'
Assert-True ($latest.cloud_function_count -ge 1) 'latest cloud function count should be >= 1'
Assert-True ($compare.latest_cloud_list_exit -eq 0) 'comparison latest cloud-list should be healthy'

$status = @{
    timestamp = (Get-Date).ToString('o')
    readonly_mcp = @{
        stable = $true
        health = @{
            probe_exit_code = $latest.probe_exit_code
            cloud_list_exit_code = $latest.cloud_list_exit_code
            cloud_function_count = $latest.cloud_function_count
            probe_duration_ms = $latest.probe_duration_ms
            cloud_list_duration_ms = $latest.cloud_list_duration_ms
        }
        baseline = @{
            probe_exit_code = $baseline.probe_exit_code
            cloud_list_exit_code = $baseline.cloud_list_exit_code
            cloud_function_count = $baseline.cloud_function_count
            probe_duration_ms = $baseline.probe_duration_ms
            cloud_list_duration_ms = $baseline.cloud_list_duration_ms
        }
        trend = @{
            probe_duration_delta_ms = [int]($latest.probe_duration_ms - $baseline.probe_duration_ms)
            cloud_list_duration_delta_ms = [int]($latest.cloud_list_duration_ms - $baseline.cloud_list_duration_ms)
            cloud_function_count_delta = [int]($latest.cloud_function_count - $baseline.cloud_function_count)
            has_previous_baseline = [bool]$compare.has_baseline
        }
    }
}

$status | ConvertTo-Json -Depth 8 | Set-Content -Path $statusPath -Encoding UTF8

New-TestResult -Name 'mcp-readonly-status' -Data @{
    pass = $true
    exit_code = 0
    status_report = $statusPath
    cloud_function_count = $latest.cloud_function_count
    stable = $status.readonly_mcp.stable
}

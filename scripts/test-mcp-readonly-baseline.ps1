param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$artifactsRoot = Join-Path $repoRoot 'artifacts'
$latestPath = Join-Path $artifactsRoot 'mcp-readonly-health-latest.json'
$baselinePath = Join-Path $artifactsRoot 'mcp-readonly-health-baseline.json'
$comparePath = Join-Path $artifactsRoot 'mcp-readonly-baseline-latest.json'

Assert-True (Test-Path $latestPath) 'latest readonly health report should exist'
$latest = Get-Content $latestPath -Raw | ConvertFrom-Json

Assert-True ($latest.probe_exit_code -in @(0, 1, 2)) "probe exit code must be known, actual=$($latest.probe_exit_code)"
Assert-Equal $latest.cloud_list_exit_code 0 'cloud-list should be healthy in latest report'
Assert-True ($latest.cloud_function_count -ge 1) "cloud function count should be >=1, actual=$($latest.cloud_function_count)"
Assert-True ($latest.probe_duration_ms -lt 25000) "probe duration should stay below 25s, actual=$($latest.probe_duration_ms)ms"
Assert-True ($latest.cloud_list_duration_ms -lt 25000) "cloud-list duration should stay below 25s, actual=$($latest.cloud_list_duration_ms)ms"

$hasBaseline = Test-Path $baselinePath
$baseline = $null
if ($hasBaseline) {
    $baseline = Get-Content $baselinePath -Raw | ConvertFrom-Json
    Assert-Equal $baseline.cloud_list_exit_code 0 'previous baseline cloud-list should be healthy'
}

$comparison = @{
    timestamp                 = (Get-Date).ToString('o')
    has_baseline              = $hasBaseline
    latest_probe_exit_code    = $latest.probe_exit_code
    latest_cloud_list_exit    = $latest.cloud_list_exit_code
    latest_cloud_func_count   = $latest.cloud_function_count
    latest_probe_duration_ms  = $latest.probe_duration_ms
    latest_list_duration_ms   = $latest.cloud_list_duration_ms
    baseline_probe_exit_code  = if ($baseline) { $baseline.probe_exit_code } else { $null }
    baseline_cloud_list_exit  = if ($baseline) { $baseline.cloud_list_exit_code } else { $null }
    baseline_cloud_func_count = if ($baseline) { $baseline.cloud_function_count } else { $null }
    baseline_probe_duration_ms = if ($baseline) { $baseline.probe_duration_ms } else { $null }
    baseline_list_duration_ms  = if ($baseline) { $baseline.cloud_list_duration_ms } else { $null }
}

$comparison | ConvertTo-Json -Depth 6 | Set-Content -Path $comparePath -Encoding UTF8
Copy-Item -Path $latestPath -Destination $baselinePath -Force

New-TestResult -Name 'mcp-readonly-baseline' -Data @{
    pass                 = $true
    exit_code            = 0
    has_baseline         = $hasBaseline
    latest_report        = $latestPath
    baseline_report      = $baselinePath
    comparison_report    = $comparePath
    cloud_function_count = $latest.cloud_function_count
}

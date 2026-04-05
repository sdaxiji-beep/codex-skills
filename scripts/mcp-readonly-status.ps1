[CmdletBinding()]
param(
    [switch]$AsJson
)

$repoRoot = Split-Path $PSScriptRoot -Parent
$artifactsRoot = Join-Path $repoRoot 'artifacts'
$statusPath = Join-Path $artifactsRoot 'mcp-readonly-status-latest.json'

if (-not (Test-Path $statusPath)) {
    throw "Status file not found: $statusPath"
}

$status = Get-Content $statusPath -Raw | ConvertFrom-Json

if ($AsJson) {
    $status | ConvertTo-Json -Depth 10
    exit 0
}

$health = $status.readonly_mcp.health
$baseline = $status.readonly_mcp.baseline
$trend = $status.readonly_mcp.trend

[pscustomobject]@{
    stable                         = [bool]$status.readonly_mcp.stable
    cloud_function_count           = [int]$health.cloud_function_count
    probe_exit_code                = [int]$health.probe_exit_code
    cloud_list_exit_code           = [int]$health.cloud_list_exit_code
    probe_duration_ms              = [int]$health.probe_duration_ms
    cloud_list_duration_ms         = [int]$health.cloud_list_duration_ms
    baseline_probe_duration_ms     = [int]$baseline.probe_duration_ms
    baseline_cloud_list_duration_ms = [int]$baseline.cloud_list_duration_ms
    probe_duration_delta_ms        = [int]$trend.probe_duration_delta_ms
    cloud_list_duration_delta_ms   = [int]$trend.cloud_list_duration_delta_ms
    baseline_exists                = [bool]$trend.has_previous_baseline
    timestamp                      = $status.timestamp
} | Format-List

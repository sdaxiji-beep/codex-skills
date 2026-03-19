[CmdletBinding()]
param(
    [int]$KeepLast = 200
)

$repoRoot = Split-Path $PSScriptRoot -Parent
$artifactsRoot = Join-Path $repoRoot 'artifacts'
$statusPath = Join-Path $artifactsRoot 'mcp-readonly-status-latest.json'
$historyPath = Join-Path $artifactsRoot 'mcp-readonly-status-history.jsonl'

if (-not (Test-Path $statusPath)) {
    throw "Status file not found: $statusPath"
}

$status = Get-Content $statusPath -Raw | ConvertFrom-Json
$entry = @{
    timestamp = (Get-Date).ToString('o')
    stable = [bool]$status.readonly_mcp.stable
    cloud_function_count = [int]$status.readonly_mcp.health.cloud_function_count
    probe_exit_code = [int]$status.readonly_mcp.health.probe_exit_code
    cloud_list_exit_code = [int]$status.readonly_mcp.health.cloud_list_exit_code
    probe_duration_ms = [int]$status.readonly_mcp.health.probe_duration_ms
    cloud_list_duration_ms = [int]$status.readonly_mcp.health.cloud_list_duration_ms
    probe_duration_delta_ms = [int]$status.readonly_mcp.trend.probe_duration_delta_ms
    cloud_list_duration_delta_ms = [int]$status.readonly_mcp.trend.cloud_list_duration_delta_ms
}

New-Item -ItemType Directory -Force -Path $artifactsRoot | Out-Null
Add-Content -Path $historyPath -Value ($entry | ConvertTo-Json -Compress)

$lines = Get-Content $historyPath
if ($lines.Count -gt $KeepLast) {
    $lines | Select-Object -Last $KeepLast | Set-Content -Path $historyPath -Encoding UTF8
}

[pscustomobject]@{
    history_path = $historyPath
    appended = $true
    keep_last = $KeepLast
    current_lines = (Get-Content $historyPath).Count
} | ConvertTo-Json -Depth 5

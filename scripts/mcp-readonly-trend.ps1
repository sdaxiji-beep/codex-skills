[CmdletBinding()]
param(
    [int]$Window = 20,
    [switch]$AsJson
)

if ($Window -lt 1) {
    throw "Window must be >= 1"
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$historyPath = Join-Path $repoRoot 'artifacts\mcp-readonly-status-history.jsonl'

if (-not (Test-Path $historyPath)) {
    throw "History file not found: $historyPath"
}

$lines = Get-Content $historyPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
if ($lines.Count -eq 0) {
    throw "History file is empty: $historyPath"
}

$records = @()
foreach ($line in $lines) {
    try {
        $records += ($line | ConvertFrom-Json)
    } catch {
        # Skip malformed history lines.
    }
}

if ($records.Count -eq 0) {
    throw "No valid history records found: $historyPath"
}

$recent = @($records | Select-Object -Last $Window)
$total = $recent.Count
$stableCount = @($recent | Where-Object { $_.stable -eq $true }).Count
$unstableCount = $total - $stableCount
$cloudHealthyCount = @($recent | Where-Object { $_.cloud_list_exit_code -eq 0 }).Count
$probeKnownCount = @($recent | Where-Object { $_.probe_exit_code -in @(0,1,2) }).Count

$avgProbe = [math]::Round((@($recent | Measure-Object -Property probe_duration_ms -Average)[0].Average), 2)
$avgList = [math]::Round((@($recent | Measure-Object -Property cloud_list_duration_ms -Average)[0].Average), 2)
$maxProbe = @($recent | Measure-Object -Property probe_duration_ms -Maximum)[0].Maximum
$maxList = @($recent | Measure-Object -Property cloud_list_duration_ms -Maximum)[0].Maximum
$last = $recent[-1]

$summary = @{
    timestamp = (Get-Date).ToString('o')
    history_path = $historyPath
    window = $Window
    total_in_window = $total
    stable_count = $stableCount
    unstable_count = $unstableCount
    cloud_list_healthy_count = $cloudHealthyCount
    probe_known_exit_count = $probeKnownCount
    avg_probe_duration_ms = $avgProbe
    avg_cloud_list_duration_ms = $avgList
    max_probe_duration_ms = [int]$maxProbe
    max_cloud_list_duration_ms = [int]$maxList
    last_snapshot = @{
        timestamp = $last.timestamp
        stable = [bool]$last.stable
        probe_exit_code = [int]$last.probe_exit_code
        cloud_list_exit_code = [int]$last.cloud_list_exit_code
        cloud_function_count = [int]$last.cloud_function_count
        probe_duration_ms = [int]$last.probe_duration_ms
        cloud_list_duration_ms = [int]$last.cloud_list_duration_ms
    }
}

if ($AsJson) {
    $summary | ConvertTo-Json -Depth 8
    exit 0
}

[pscustomobject]$summary | Format-List

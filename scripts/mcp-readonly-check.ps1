[CmdletBinding()]
param(
    [int]$Window = 20,
    [int]$KeepLast = 200,
    [switch]$AsJson
)

$statusScript = Join-Path $PSScriptRoot 'mcp-readonly-status.ps1'
$historyScript = Join-Path $PSScriptRoot 'mcp-readonly-status-history.ps1'
$trendScript = Join-Path $PSScriptRoot 'mcp-readonly-trend.ps1'
$repoRoot = Split-Path $PSScriptRoot -Parent
$artifactsRoot = Join-Path $repoRoot 'artifacts'
$checkPath = Join-Path $artifactsRoot 'mcp-readonly-check-latest.json'

foreach ($script in @($statusScript, $historyScript, $trendScript)) {
    if (-not (Test-Path $script)) {
        throw "Required script not found: $script"
    }
}

$errors = @()
$status = $null
$history = $null
$trend = $null

try {
    $statusRaw = & $statusScript -AsJson 2>&1 | Out-String
    $status = $statusRaw | ConvertFrom-Json
} catch {
    $errors += "status_failed: $($_.Exception.Message)"
}

try {
    $historyRaw = & $historyScript -KeepLast $KeepLast 2>&1 | Out-String
    $history = $historyRaw | ConvertFrom-Json
} catch {
    $errors += "history_failed: $($_.Exception.Message)"
}

try {
    $trendRaw = & $trendScript -Window $Window -AsJson 2>&1 | Out-String
    $trend = $trendRaw | ConvertFrom-Json
} catch {
    $errors += "trend_failed: $($_.Exception.Message)"
}

$stable = $false
if ($status -and $trend) {
    $stable = (
        $status.readonly_mcp.stable -eq $true -and
        $status.readonly_mcp.health.cloud_list_exit_code -eq 0 -and
        $status.readonly_mcp.health.cloud_function_count -ge 1 -and
        $trend.stable_count -ge 1 -and
        $trend.cloud_list_healthy_count -ge 1
    )
}

$result = @{
    timestamp = (Get-Date).ToString('o')
    stable = $stable
    window = $Window
    keep_last = $KeepLast
    status = $status
    history = $history
    trend = $trend
    errors = $errors
}

New-Item -ItemType Directory -Force -Path $artifactsRoot | Out-Null
$result | ConvertTo-Json -Depth 12 | Set-Content -Path $checkPath -Encoding UTF8

if ($AsJson) {
    $result | ConvertTo-Json -Depth 12
    exit 0
}

[pscustomobject]@{
    stable = $stable
    errors = ($errors -join '; ')
    check_report = $checkPath
    cloud_function_count = if ($status) { [int]$status.readonly_mcp.health.cloud_function_count } else { 0 }
    trend_window_count = if ($trend) { [int]$trend.total_in_window } else { 0 }
} | Format-List

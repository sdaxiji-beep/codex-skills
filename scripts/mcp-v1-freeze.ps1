[CmdletBinding()]
param(
    [int]$Window = 20,
    [int]$KeepLast = 200,
    [int]$CacheTtlSeconds = 180,
    [switch]$UseRecentArtifacts,
    [switch]$AsJson
)

$readonlyScript = Join-Path $PSScriptRoot 'mcp-readonly-check.ps1'
$safetyScript = Join-Path $PSScriptRoot 'mcp-safety-check.ps1'
$repoRoot = Split-Path $PSScriptRoot -Parent
$artifactPath = Join-Path $repoRoot 'artifacts\mcp-v1-freeze.json'

foreach ($script in @($readonlyScript, $safetyScript)) {
    if (-not (Test-Path $script)) {
        throw "Required script not found: $script"
    }
}

$errors = @()
$readonly = $null
$safety = $null

if (-not $PSBoundParameters.ContainsKey('UseRecentArtifacts')) {
    $UseRecentArtifacts = $true
}

function Get-RecentJsonArtifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][int]$TtlSeconds
    )

    if (-not (Test-Path $Path)) { return $null }
    $age = ((Get-Date) - (Get-Item $Path).LastWriteTime).TotalSeconds
    if ($age -gt $TtlSeconds) { return $null }
    try {
        return Get-Content $Path -Raw | ConvertFrom-Json
    }
    catch {
        return $null
    }
}

$readonlyArtifactPath = Join-Path $repoRoot 'artifacts\mcp-readonly-check-latest.json'
$safetyArtifactPath = Join-Path $repoRoot 'artifacts\mcp-safety-check-latest.json'

try {
    if ($UseRecentArtifacts) {
        $readonly = Get-RecentJsonArtifact -Path $readonlyArtifactPath -TtlSeconds $CacheTtlSeconds
    }
    if (-not $readonly) {
        $readonlyRaw = & $readonlyScript -Window $Window -KeepLast $KeepLast -AsJson 2>&1 | Out-String
        $readonly = $readonlyRaw | ConvertFrom-Json
    }
} catch {
    $errors += "readonly_check_failed: $($_.Exception.Message)"
}

try {
    if ($UseRecentArtifacts) {
        $safety = Get-RecentJsonArtifact -Path $safetyArtifactPath -TtlSeconds $CacheTtlSeconds
    }
    if (-not $safety) {
        $safetyRaw = & $safetyScript -Window $Window -KeepLast $KeepLast -AsJson 2>&1 | Out-String
        $safety = $safetyRaw | ConvertFrom-Json
    }
} catch {
    $errors += "safety_check_failed: $($_.Exception.Message)"
}

$freeze = [ordered]@{
    version = 'mcp_v1_freeze_snapshot'
    timestamp = (Get-Date).ToString('o')
    window = $Window
    keep_last = $KeepLast
    cache_ttl_seconds = $CacheTtlSeconds
    use_recent_artifacts = [bool]$UseRecentArtifacts
    stable = ($readonly -and $readonly.stable -eq $true)
    write_guarded = ($safety -and $safety.write_gate.blocked -eq $true -and $safety.write_readiness.can_enable -eq $false)
    ok = ($errors.Count -eq 0 -and $readonly.stable -eq $true -and $safety.ok -eq $true)
    baseline = [ordered]@{
        cloud_function_count = if ($readonly) { [int]$readonly.status.readonly_mcp.health.cloud_function_count } else { 0 }
        trend_window = if ($readonly) { [int]$readonly.trend.total_in_window } else { 0 }
        trend_stable_count = if ($readonly) { [int]$readonly.trend.stable_count } else { 0 }
        probe_exit_code = if ($readonly) { [int]$readonly.status.readonly_mcp.health.probe_exit_code } else { -1 }
        cloud_list_exit_code = if ($readonly) { [int]$readonly.status.readonly_mcp.health.cloud_list_exit_code } else { -1 }
    }
    errors = @($errors)
}

New-Item -ItemType Directory -Force -Path (Split-Path $artifactPath) | Out-Null
$freeze | ConvertTo-Json -Depth 10 | Set-Content -Path $artifactPath -Encoding UTF8

if ($AsJson) {
    $freeze | ConvertTo-Json -Depth 10
    exit 0
}

[pscustomobject]@{
    ok = $freeze.ok
    stable = $freeze.stable
    write_guarded = $freeze.write_guarded
    cloud_function_count = $freeze.baseline.cloud_function_count
    artifact = $artifactPath
    errors = ($freeze.errors -join '; ')
} | Format-List

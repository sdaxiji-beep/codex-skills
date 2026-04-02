[CmdletBinding()]
param(
    [int]$Window = 20,
    [int]$KeepLast = 200,
    [int]$CacheTtlSeconds = 180,
    [switch]$UseRecentArtifacts,
    [switch]$AsJson
)

$readonlyScript = Join-Path $PSScriptRoot 'mcp-readonly-check.ps1'
$writeGateScript = Join-Path $PSScriptRoot 'mcp-write-gate-status.ps1'
$writeReadinessScript = Join-Path $PSScriptRoot 'mcp-write-readiness.ps1'
$repoRoot = Split-Path $PSScriptRoot -Parent
$artifactsRoot = Join-Path $repoRoot 'artifacts'
$reportPath = Join-Path $artifactsRoot 'mcp-safety-check-latest.json'

foreach ($script in @($readonlyScript, $writeGateScript, $writeReadinessScript)) {
    if (-not (Test-Path $script)) {
        throw "Required script not found: $script"
    }
}

$errors = @()
$readonly = $null
$writeGate = $null
$writeReadiness = $null

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

$readonlyArtifactPath = Join-Path $artifactsRoot 'mcp-readonly-check-latest.json'
$writeGateArtifactPath = Join-Path $artifactsRoot 'mcp-write-gate-status-latest.json'
$writeReadinessArtifactPath = Join-Path $artifactsRoot 'mcp-write-readiness-latest.json'

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
        $writeGate = Get-RecentJsonArtifact -Path $writeGateArtifactPath -TtlSeconds $CacheTtlSeconds
    }
    if (-not $writeGate) {
        $writeGateRaw = & $writeGateScript -AsJson 2>&1 | Out-String
        $writeGate = $writeGateRaw | ConvertFrom-Json
    }
} catch {
    $errors += "write_gate_status_failed: $($_.Exception.Message)"
}

try {
    if ($UseRecentArtifacts) {
        $writeReadiness = Get-RecentJsonArtifact -Path $writeReadinessArtifactPath -TtlSeconds $CacheTtlSeconds
    }
    if (-not $writeReadiness) {
        $writeMcpEnabled = ($env:WECHAT_WRITE_MCP_ENABLE -eq '1')
        $previewToolEnabled = ($env:WECHAT_WRITE_TOOL_PREVIEW_ENABLE -eq '1')
        if (-not $writeMcpEnabled -and -not $previewToolEnabled) {
            $writeReadiness = [pscustomobject]@{
                can_enable = $false
                source = 'derived_fast_default_gate_closed'
            }
        }
        else {
            $writeReadinessRaw = & $writeReadinessScript -AsJson 2>&1 | Out-String
            $writeReadiness = $writeReadinessRaw | ConvertFrom-Json
        }
    }
} catch {
    $errors += "write_readiness_failed: $($_.Exception.Message)"
}

$readonlyStable = ($readonly -and $readonly.stable -eq $true)
$writeBlockedByDefault = ($writeGate -and $writeGate.blocked -eq $true)
$writeNotEnableable = ($writeReadiness -and $writeReadiness.can_enable -eq $false)

$result = @{
    timestamp = (Get-Date).ToString('o')
    window = $Window
    keep_last = $KeepLast
    cache_ttl_seconds = $CacheTtlSeconds
    use_recent_artifacts = [bool]$UseRecentArtifacts
    ok = ($errors.Count -eq 0 -and $readonlyStable -and $writeBlockedByDefault -and $writeNotEnableable)
    readonly = @{
        stable = $readonlyStable
        payload = $readonly
    }
    write_gate = @{
        blocked = $writeBlockedByDefault
        payload = $writeGate
    }
    write_readiness = @{
        can_enable = if ($writeReadiness) { [bool]$writeReadiness.can_enable } else { $null }
        payload = $writeReadiness
    }
    errors = $errors
}

New-Item -ItemType Directory -Force -Path $artifactsRoot | Out-Null
$result | ConvertTo-Json -Depth 12 | Set-Content -Path $reportPath -Encoding UTF8

if ($AsJson) {
    $result | ConvertTo-Json -Depth 12
    exit 0
}

[pscustomobject]@{
    ok = $result.ok
    readonly_stable = $readonlyStable
    write_blocked_by_default = $writeBlockedByDefault
    write_can_enable = if ($writeReadiness) { [bool]$writeReadiness.can_enable } else { $null }
    errors = ($errors -join '; ')
    report = $reportPath
} | Format-List

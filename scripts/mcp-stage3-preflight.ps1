[CmdletBinding()]
param(
    [int]$Window = 20,
    [int]$KeepLast = 200,
    [switch]$AsJson
)

$freezeScript = Join-Path $PSScriptRoot 'mcp-v1-freeze.ps1'
$safetyScript = Join-Path $PSScriptRoot 'mcp-safety-check.ps1'
$simulationScript = Join-Path $PSScriptRoot 'mcp-write-enable-simulation.ps1'
$repoRoot = Split-Path $PSScriptRoot -Parent
$artifactPath = Join-Path $repoRoot 'artifacts\mcp-stage3-preflight-latest.json'
$freezeArtifactPath = Join-Path $repoRoot 'artifacts\mcp-v1-freeze.json'
$safetyArtifactPath = Join-Path $repoRoot 'artifacts\mcp-safety-check-latest.json'
$simulationArtifactPath = Join-Path $repoRoot 'artifacts\mcp-write-enable-simulation-latest.json'
$maxArtifactAgeSeconds = 180

foreach ($script in @($freezeScript, $safetyScript, $simulationScript)) {
    if (-not (Test-Path $script)) {
        throw "Required script not found: $script"
    }
}

function Get-RecentArtifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$MaxAgeSeconds = 180
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        $item = Get-Item $Path -ErrorAction Stop
        $age = ((Get-Date) - $item.LastWriteTime).TotalSeconds
        if ($age -gt $MaxAgeSeconds) {
            return $null
        }
        return (Get-Content $Path -Raw -ErrorAction Stop | ConvertFrom-Json)
    } catch {
        return $null
    }
}

$errors = @()
$freeze = $null
$safety = $null
$sim = $null

try {
    $freeze = Get-RecentArtifact -Path $freezeArtifactPath -MaxAgeSeconds $maxArtifactAgeSeconds
    if ($null -eq $freeze) {
        $freezeRaw = & $freezeScript -Window $Window -KeepLast $KeepLast -AsJson 2>&1 | Out-String
        $freeze = $freezeRaw | ConvertFrom-Json
    }
} catch {
    $errors += "freeze_failed: $($_.Exception.Message)"
}

try {
    $safety = Get-RecentArtifact -Path $safetyArtifactPath -MaxAgeSeconds $maxArtifactAgeSeconds
    if ($null -eq $safety) {
        $safetyRaw = & $safetyScript -Window $Window -KeepLast $KeepLast -AsJson 2>&1 | Out-String
        $safety = $safetyRaw | ConvertFrom-Json
    }
} catch {
    $errors += "safety_failed: $($_.Exception.Message)"
}

try {
    $sim = Get-RecentArtifact -Path $simulationArtifactPath -MaxAgeSeconds $maxArtifactAgeSeconds
    if ($null -eq $sim) {
        $simRaw = & $simulationScript -AsJson 2>&1 | Out-String
        $sim = $simRaw | ConvertFrom-Json
    }
} catch {
    $errors += "simulation_failed: $($_.Exception.Message)"
}

$readyForStage3Execution = (
    $errors.Count -eq 0 -and
    $freeze.ok -eq $true -and
    $safety.ok -eq $true -and
    $sim.current.can_enable -eq $false -and
    $sim.simulation.with_env.can_enable -eq $true
)

$result = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    stage = 'stage3-preflight'
    ready_for_execution_phase = $readyForStage3Execution
    freeze_ok = if ($freeze) { [bool]$freeze.ok } else { $false }
    safety_ok = if ($safety) { [bool]$safety.ok } else { $false }
    current_write_enableable = if ($sim) { [bool]$sim.current.can_enable } else { $false }
    simulated_write_enableable = if ($sim) { [bool]$sim.simulation.with_env.can_enable } else { $false }
    errors = @($errors)
    artifacts = [ordered]@{
        freeze = Join-Path $repoRoot 'artifacts\mcp-v1-freeze.json'
        safety = Join-Path $repoRoot 'artifacts\mcp-safety-check-latest.json'
        simulation = Join-Path $repoRoot 'artifacts\mcp-write-enable-simulation-latest.json'
        preflight = $artifactPath
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path $artifactPath) | Out-Null
$result | ConvertTo-Json -Depth 10 | Set-Content -Path $artifactPath -Encoding UTF8

if ($AsJson) {
    $result | ConvertTo-Json -Depth 10
    exit 0
}

[pscustomobject]@{
    ready_for_execution_phase = $result.ready_for_execution_phase
    freeze_ok = $result.freeze_ok
    safety_ok = $result.safety_ok
    current_write_enableable = $result.current_write_enableable
    simulated_write_enableable = $result.simulated_write_enableable
    errors = ($result.errors -join '; ')
    artifact = $artifactPath
} | Format-List

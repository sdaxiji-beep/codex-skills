[CmdletBinding()]
param(
    [switch]$Apply,
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
    [int]$KeepArtifacts = 400,
    [int]$KeepCaptures = 80,
    [int]$KeepGeneratedProjects = 120
)

$ErrorActionPreference = 'Stop'

function Get-RetentionCandidates {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$ItemType,
        [Parameter(Mandatory = $true)]
        [int]$Keep
    )

    if (-not (Test-Path $Path)) {
        return @{
            path = $Path
            item_type = $ItemType
            exists = $false
            total = 0
            keep = $Keep
            remove = @()
        }
    }

    $items = switch ($ItemType) {
        'file' { Get-ChildItem -Path $Path -File -Recurse | Sort-Object LastWriteTimeUtc -Descending }
        'dir'  { Get-ChildItem -Path $Path -Directory | Sort-Object LastWriteTimeUtc -Descending }
        default { throw "Unsupported item type: $ItemType" }
    }

    $remove = @($items | Select-Object -Skip $Keep)

    return @{
        path = $Path
        item_type = $ItemType
        exists = $true
        total = @($items).Count
        keep = $Keep
        remove = $remove
    }
}

function Remove-RetentionItems {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Items
    )

    foreach ($item in $Items) {
        if (Test-Path $item.FullName) {
            Remove-Item -LiteralPath $item.FullName -Recurse -Force
        }
    }
}

$artifactPlan = Get-RetentionCandidates -Path (Join-Path $RepoRoot 'artifacts') -ItemType file -Keep $KeepArtifacts
$capturePlan = Get-RetentionCandidates -Path (Join-Path $RepoRoot 'diagnostics\screenshot\captures') -ItemType file -Keep $KeepCaptures
$generatedPlan = Get-RetentionCandidates -Path (Join-Path $RepoRoot 'generated') -ItemType dir -Keep $KeepGeneratedProjects

$plans = @($artifactPlan, $capturePlan, $generatedPlan)
$allCandidates = @(
    @($artifactPlan.remove) +
    @($capturePlan.remove) +
    @($generatedPlan.remove)
)

if ($Apply) {
    Remove-RetentionItems -Items $allCandidates
}

[pscustomobject]@{
    test = 'cleanup-runtime-data'
    mode = if ($Apply) { 'apply' } else { 'dry_run' }
    pass = $true
    total_candidates = $allCandidates.Count
    plans = $plans | ForEach-Object {
        [pscustomobject]@{
            path = $_.path
            item_type = $_.item_type
            exists = $_.exists
            total = $_.total
            keep = $_.keep
            remove_count = @($_.remove).Count
        }
    }
}


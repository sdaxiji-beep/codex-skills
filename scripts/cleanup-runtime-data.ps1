[CmdletBinding()]
param(
    [switch]$Apply
)

$repoRoot = Split-Path $PSScriptRoot -Parent
$targets = @(
    (Join-Path $repoRoot 'generated'),
    (Join-Path $repoRoot 'artifacts')
)

$summary = @()
foreach ($target in $targets) {
    if (-not (Test-Path $target)) {
        $summary += [pscustomobject]@{
            path = $target
            exists = $false
            item_count = 0
            removed = 0
            mode = if ($Apply) { 'apply' } else { 'dry_run' }
        }
        continue
    }

    $items = @(Get-ChildItem $target -Force -ErrorAction SilentlyContinue)
    $removed = 0
    if ($Apply) {
        foreach ($item in $items) {
            if ($item.Name -eq '.gitkeep') { continue }
            Remove-Item $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
            $removed++
        }
    }

    $summary += [pscustomobject]@{
        path = $target
        exists = $true
        item_count = $items.Count
        removed = $removed
        mode = if ($Apply) { 'apply' } else { 'dry_run' }
    }
}

$result = [pscustomobject]@{
    status = 'success'
    mode = if ($Apply) { 'apply' } else { 'dry_run' }
    note = if ($Apply) {
        'runtime folders cleaned'
    } else {
        'no files removed, rerun with -Apply to clean'
    }
    targets = $summary
}

$result | ConvertTo-Json -Depth 6

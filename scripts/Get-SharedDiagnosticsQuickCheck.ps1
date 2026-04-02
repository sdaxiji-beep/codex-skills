. "$PSScriptRoot\Invoke-DiagnosticsQuickCheck.ps1"
. "$PSScriptRoot\Write-AtomicJsonCache.ps1"

function Get-SharedDiagnosticsQuickCheckFingerprint {
    param(
        [string]$RepoRoot
    )

    $roots = @(
        (Join-Path $RepoRoot 'diagnostics'),
        (Join-Path $RepoRoot 'scripts\Invoke-DiagnosticsQuickCheck.ps1'),
        (Join-Path $RepoRoot 'scripts\Get-SharedDiagnosticsQuickCheck.ps1'),
        (Join-Path $RepoRoot 'scripts\test-diagnostics-focused.ps1'),
        (Join-Path $RepoRoot 'scripts\test-wechat-mcp-server-inventory.ps1'),
        (Join-Path $RepoRoot 'scripts\wechat-mcp-server.mjs')
    )

    $entries = New-Object System.Collections.Generic.List[string]
    foreach ($root in $roots) {
        if (-not (Test-Path $root)) {
            continue
        }

        $item = Get-Item $root -ErrorAction SilentlyContinue
        if ($null -eq $item) {
            continue
        }

        if (-not $item.PSIsContainer) {
            $entries.Add(('{0}|{1}' -f $item.FullName.ToLowerInvariant(), $item.LastWriteTimeUtc.Ticks))
            continue
        }

        Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '\\(artifacts|sandbox|generated|node_modules)\\' -and
                $_.FullName -notmatch '\\diagnostics\\screenshot\\captures\\'
            } |
            ForEach-Object {
                $entries.Add(('{0}|{1}' -f $_.FullName.ToLowerInvariant(), $_.LastWriteTimeUtc.Ticks))
            }
    }

    $hashInput = ($entries | Sort-Object) -join "`n"
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($hashInput)
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-SharedDiagnosticsQuickCheckResult {
    param(
        [string]$RepoRoot,
        [switch]$ForceRefresh
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Split-Path $PSScriptRoot -Parent
    }

    $artifactDir = Join-Path $RepoRoot 'artifacts\wechat-devtools\diagnostics'
    $cachePath = Join-Path $artifactDir 'shared-quickcheck-cache.json'
    $summaryPath = Join-Path $artifactDir 'shared-quickcheck-summary.json'
    $fingerprint = Get-SharedDiagnosticsQuickCheckFingerprint -RepoRoot $RepoRoot

    if (-not $ForceRefresh -and (Test-Path $cachePath)) {
        try {
            $cached = Get-Content -Path $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            # Prefer the deterministic repo-relative summary path; cached path text can drift in non-ASCII environments.
            if ($cached.fingerprint -eq $fingerprint -and (Test-Path $summaryPath)) {
                $summary = Get-Content -Path $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
                return [pscustomobject]@{
                    fingerprint  = $fingerprint
                    summary      = $summary
                    artifactPath = $summaryPath
                    cachePath    = $cachePath
                    fromCache    = $true
                }
            }
        }
        catch {
        }
    }

    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
    $summary = Invoke-DiagnosticsQuickCheck -Quiet -OutputPath $summaryPath
    $payload = [pscustomobject]@{
        fingerprint  = $fingerprint
        artifact_path = $summaryPath
        generated_at = (Get-Date).ToString('o')
        summary      = $summary
    }
    Write-AtomicJsonCache -Path $cachePath -InputObject $payload -Depth 10

    return [pscustomobject]@{
        fingerprint  = $fingerprint
        summary      = $summary
        artifactPath = $summaryPath
        cachePath    = $cachePath
        fromCache    = $false
    }
}

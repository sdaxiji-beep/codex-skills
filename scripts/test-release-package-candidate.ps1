param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\Get-SharedDiagnosticsQuickCheck.ps1"

function Get-ReleasePackageCandidateFingerprint {
    param([string]$RepoRoot)

    $manifestPath = Join-Path $RepoRoot 'release-package.manifest.json'
    Assert-True (Test-Path $manifestPath) 'release-package.manifest.json should exist'

    $manifest = Get-Content -Path $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $paths = New-Object System.Collections.Generic.List[string]
    $paths.Add($manifestPath)

    foreach ($relative in @(
        '.gitignore',
        'README.md',
        'RELEASE_PACKAGE.md'
    )) {
        $candidate = Join-Path $RepoRoot $relative
        if (Test-Path $candidate) {
            $paths.Add($candidate)
        }
    }

    foreach ($entry in @($manifest.include)) {
        $fullPath = Join-Path $RepoRoot $entry
        if (-not (Test-Path $fullPath)) {
            continue
        }

        $item = Get-Item $fullPath -ErrorAction SilentlyContinue
        if ($null -eq $item) {
            continue
        }

        if ($item.PSIsContainer) {
            Get-ChildItem -Path $fullPath -Recurse -File -ErrorAction SilentlyContinue |
                ForEach-Object {
                    $paths.Add($_.FullName)
                }
        }
        else {
            $paths.Add($item.FullName)
        }
    }

    $builder = New-Object System.Collections.Generic.List[string]
    foreach ($path in ($paths | Sort-Object -Unique)) {
        $item = Get-Item $path -ErrorAction SilentlyContinue
        if ($null -eq $item -or $item.PSIsContainer) {
            continue
        }

        $builder.Add(('{0}|{1}' -f $item.FullName.ToLowerInvariant(), $item.LastWriteTimeUtc.Ticks))
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes(($builder -join "`n"))
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-SharedReleasePackageCandidateResult {
    param([string]$RepoRoot)

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Split-Path $PSScriptRoot -Parent
    }

    $cacheDir = Join-Path $RepoRoot 'artifacts\wechat-devtools\release-package'
    $cachePath = Join-Path $cacheDir 'release-package-candidate-cache.json'
    $scriptPath = Join-Path $PSScriptRoot 'check-release-package.ps1'
    Assert-True (Test-Path $scriptPath) 'check-release-package.ps1 should exist'

    $fingerprint = Get-ReleasePackageCandidateFingerprint -RepoRoot $RepoRoot
    if (Test-Path $cachePath) {
        try {
            $cached = Get-Content -Path $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            if ($cached.cache_version -eq 1 -and $cached.fingerprint -eq $fingerprint -and $cached.result) {
                return [pscustomobject]@{
                    cachePath   = $cachePath
                    fingerprint = $fingerprint
                    fromCache   = $true
                    result      = $cached.result
                }
            }
        }
        catch {
        }
    }

    $result = & $scriptPath
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    $payload = [pscustomobject]@{
        cache_version = 1
        fingerprint   = $fingerprint
        generated_at  = (Get-Date).ToString('o')
        result        = $result
    }
    $payload | ConvertTo-Json -Depth 12 | Set-Content -Path $cachePath -Encoding UTF8

    return [pscustomobject]@{
        cachePath   = $cachePath
        fingerprint = $fingerprint
        fromCache   = $false
        result      = $result
    }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$sharedRelease = Get-SharedReleasePackageCandidateResult -RepoRoot $repoRoot
$result = $sharedRelease.result

$diagArtifactPath = $null
$diagSummary = $null

if ($null -ne $Context -and $Context.ContainsKey('DiagnosticsQuickCheckSummary') -and $Context.ContainsKey('DiagnosticsQuickCheckArtifactPath')) {
    $diagSummary = $Context.DiagnosticsQuickCheckSummary
    $diagArtifactPath = [string]$Context.DiagnosticsQuickCheckArtifactPath
}
else {
    $sharedDiagnostics = Get-SharedDiagnosticsQuickCheckResult
    $diagSummary = $sharedDiagnostics.summary
    $diagArtifactPath = [string]$sharedDiagnostics.artifactPath

    if ($null -ne $Context) {
        $Context.DiagnosticsQuickCheckSummary = $diagSummary
        $Context.DiagnosticsQuickCheckArtifactPath = $diagArtifactPath
    }
}

Assert-True ([bool]$diagSummary.pass) 'diagnostics quickcheck should pass before release candidate passes'
Assert-True (Test-Path $diagArtifactPath) 'diagnostics quickcheck artifact should be written'
$diagArtifact = Get-Content -Path $diagArtifactPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-True ($diagArtifact.PSObject.Properties.Name -contains 'pass') 'diagnostics artifact should contain pass'
Assert-True ($diagArtifact.PSObject.Properties.Name -contains 'results') 'diagnostics artifact should contain results'
Assert-True ($diagArtifact.PSObject.Properties.Name -contains 'timestamp') 'diagnostics artifact should contain timestamp'
Assert-Equal ([bool]$diagArtifact.pass) $true 'diagnostics artifact pass should be true'
Assert-True (@($diagArtifact.results).Count -ge 1) 'diagnostics artifact should include at least one test result'

Assert-Equal $result.version 'release_package_v1' 'release manifest version should match'
Assert-True ($result.missing_includes.Count -eq 0) 'release package should not miss required includes'
Assert-True ($result.missing_exclude_rules.Count -eq 0) 'release package should not miss exclude gitignore rules'
Assert-True ($result.missing_doc_mentions.Count -eq 0) 'release package doc should mention all excludes'
Assert-True ($result.blocked_files_present.Count -eq 0) 'blocked root release files should not be present'
Assert-True ($result.hygiene_findings.Count -eq 0) 'release package should not expose rooted machine-specific paths'
Assert-True ([bool]$result.pass) 'release package candidate should pass'

New-TestResult -Name 'release-package-candidate' -Data @{
    pass = $true
    exit_code = 0
    version = $result.version
    diagnostics_total = $diagSummary.total
    diagnostics_passed = $diagSummary.passed
    diagnostics_artifact = $diagArtifactPath
    release_package_cache = $sharedRelease.cachePath
    release_package_cache_hit = $sharedRelease.fromCache
}

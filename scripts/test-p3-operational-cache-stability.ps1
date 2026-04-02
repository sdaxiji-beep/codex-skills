param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\Get-SharedDiagnosticsQuickCheck.ps1"

if ($null -eq $Context) {
    $Context = @{}
}

$repoRoot = Split-Path $PSScriptRoot -Parent

$p3First = Get-SharedP3OperationalFixtures -RepoRoot $repoRoot -ForceRefresh
$p3Second = Get-SharedP3OperationalFixtures -RepoRoot $repoRoot
$p3Cache = Get-Content -Path $p3First.cachePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop

$diagFirst = Get-SharedDiagnosticsQuickCheckResult -RepoRoot $repoRoot -ForceRefresh
$diagSecond = Get-SharedDiagnosticsQuickCheckResult -RepoRoot $repoRoot
$diagCache = Get-Content -Path $diagFirst.cachePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop

Assert-True ($p3Second.fromCache) 'shared P3 fixtures should reuse the cache after normalization'
Assert-Equal $p3Cache.generated_project.appid 'touristappid' 'shared P3 cache should stay normalized'
Assert-Equal $p3Cache.generated_project.projectname 'notebook-app' 'shared P3 cache should stay normalized'
Assert-True ($diagSecond.fromCache) 'shared diagnostics cache should reuse the cache'
Assert-Equal $diagCache.artifact_path $diagFirst.artifactPath 'shared diagnostics cache should keep a stable artifact path'
Assert-True ($null -ne $diagCache.summary) 'shared diagnostics cache should persist a summary payload'

New-TestResult -Name 'p3-operational-cache-stability' -Data @{
    pass = $true
    exit_code = 0
    p3_cache_path = $p3Second.cachePath
    p3_from_cache = $p3Second.fromCache
    diagnostics_cache_path = $diagSecond.cachePath
    diagnostics_from_cache = $diagSecond.fromCache
}

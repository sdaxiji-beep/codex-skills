param()

$repoRoot = Split-Path $PSScriptRoot -Parent

$readmePath = Join-Path $repoRoot 'README.md'
$surfacePath = Join-Path $repoRoot 'PUBLIC_API_SURFACE.md'
$releasePath = Join-Path $repoRoot 'RELEASE_PACKAGE.md'

foreach ($path in @($readmePath, $surfacePath, $releasePath)) {
    if (-not (Test-Path $path)) {
        throw "Missing doc: $path"
    }
}

$readme = Get-Content -Path $readmePath -Raw -Encoding UTF8
$surface = Get-Content -Path $surfacePath -Raw -Encoding UTF8
$release = Get-Content -Path $releasePath -Raw -Encoding UTF8

$checks = @(
    @{ Name = 'README server.json'; Text = $readme; Token = 'server.json' },
    @{ Name = 'README mcpName'; Text = $readme; Token = 'mcpName' },
    @{ Name = 'README P3 distribution'; Text = $readme; Token = 'P3 distribution readiness' },
    @{ Name = 'Surface server.json'; Text = $surface; Token = 'server.json' },
    @{ Name = 'Surface mcpName'; Text = $surface; Token = 'mcpName' },
    @{ Name = 'Surface distribution metadata'; Text = $surface; Token = 'Distribution metadata' },
    @{ Name = 'Release server.json'; Text = $release; Token = 'server.json' },
    @{ Name = 'Release distribution metadata'; Text = $release; Token = 'Distribution metadata' }
)

$missing = New-Object System.Collections.Generic.List[string]

foreach ($check in $checks) {
    if ($check.Text -notmatch [regex]::Escape($check.Token)) {
        $missing.Add($check.Name)
    }
}

$rootedPattern = '[A-Za-z]:\\\\'
$rootedFindings = @()
foreach ($item in @(
    @{ Name = 'README'; Text = $readme },
    @{ Name = 'PUBLIC_API_SURFACE'; Text = $surface },
    @{ Name = 'RELEASE_PACKAGE'; Text = $release }
)) {
    if ($item.Text -match $rootedPattern) {
        $rootedFindings += $item.Name
    }
}

$result = [pscustomobject]@{
    test = 'p3-distribution-docs'
    pass = ($missing.Count -eq 0 -and $rootedFindings.Count -eq 0)
    missing = @($missing)
    rooted_findings = @($rootedFindings)
    exit_code = $(if ($missing.Count -eq 0 -and $rootedFindings.Count -eq 0) { 0 } else { 1 })
}

$result | ConvertTo-Json -Depth 4
exit $result.exit_code

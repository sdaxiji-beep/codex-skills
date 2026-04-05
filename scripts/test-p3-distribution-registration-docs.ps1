param()

$repoRoot = Split-Path $PSScriptRoot -Parent

$readmePath = Join-Path $repoRoot 'README.md'
$surfacePath = Join-Path $repoRoot 'PUBLIC_API_SURFACE.md'
$releasePath = Join-Path $repoRoot 'RELEASE_PACKAGE.md'
$readinessPath = Join-Path $repoRoot 'MCP_REGISTRY_READINESS.md'

foreach ($path in @($readmePath, $surfacePath, $releasePath, $readinessPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing doc: $path"
    }
}

$readme = Get-Content -Path $readmePath -Raw -Encoding UTF8
$surface = Get-Content -Path $surfacePath -Raw -Encoding UTF8
$release = Get-Content -Path $releasePath -Raw -Encoding UTF8
$readiness = Get-Content -Path $readinessPath -Raw -Encoding UTF8

$checks = @(
    @{ Name = 'README registry readiness'; Text = $readme; Token = 'MCP_REGISTRY_READINESS.md' },
    @{ Name = 'README installer-ready hint'; Text = $readme; Token = 'wechat://installer-readiness' },
    @{ Name = 'Surface registry readiness'; Text = $surface; Token = 'MCP_REGISTRY_READINESS.md' },
    @{ Name = 'Surface installer-ready hint'; Text = $surface; Token = 'wechat://installer-readiness' },
    @{ Name = 'Release registry readiness'; Text = $release; Token = 'MCP_REGISTRY_READINESS.md' },
    @{ Name = 'Release installer-ready hint'; Text = $release; Token = 'wechat://installer-readiness' },
    @{ Name = 'Readiness installer publication work'; Text = $readiness; Token = 'installer publication work' },
    @{ Name = 'Readiness repo-relative'; Text = $readiness; Token = 'repo-relative' }
)

$missing = New-Object System.Collections.Generic.List[string]
foreach ($check in $checks) {
    if ($check.Text -notmatch [regex]::Escape($check.Token)) {
        $missing.Add($check.Name)
    }
}

$rootedPattern = '[A-Za-z]:\\'
$rootedFindings = @()
foreach ($item in @(
    @{ Name = 'README'; Text = $readme },
    @{ Name = 'PUBLIC_API_SURFACE'; Text = $surface },
    @{ Name = 'RELEASE_PACKAGE'; Text = $release },
    @{ Name = 'MCP_REGISTRY_READINESS'; Text = $readiness }
)) {
    if ($item.Text -match $rootedPattern) {
        $rootedFindings += $item.Name
    }
}

$result = [pscustomobject]@{
    test = 'p3-distribution-registration-docs'
    pass = ($missing.Count -eq 0 -and $rootedFindings.Count -eq 0)
    missing = @($missing)
    rooted_findings = @($rootedFindings)
    exit_code = $(if ($missing.Count -eq 0 -and $rootedFindings.Count -eq 0) { 0 } else { 1 })
}

$result | ConvertTo-Json -Depth 4
exit $result.exit_code

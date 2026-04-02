param()

$repoRoot = Split-Path $PSScriptRoot -Parent

$readmePath = Join-Path $repoRoot 'README.md'
$surfacePath = Join-Path $repoRoot 'PUBLIC_API_SURFACE.md'
$releasePath = Join-Path $repoRoot 'RELEASE_PACKAGE.md'
$checklistPath = Join-Path $repoRoot 'EXECUTION_CHECKLIST.md'
$readinessPath = Join-Path $repoRoot 'MCP_REGISTRY_READINESS.md'

foreach ($path in @($readmePath, $surfacePath, $releasePath, $checklistPath, $readinessPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing doc: $path"
    }
}

$readme = Get-Content -Path $readmePath -Raw -Encoding UTF8
$surface = Get-Content -Path $surfacePath -Raw -Encoding UTF8
$release = Get-Content -Path $releasePath -Raw -Encoding UTF8
$checklist = Get-Content -Path $checklistPath -Raw -Encoding UTF8
$readiness = Get-Content -Path $readinessPath -Raw -Encoding UTF8

$checks = @(
    @{ Name = 'README registry readiness'; Text = $readme; Token = 'MCP_REGISTRY_READINESS.md' },
    @{ Name = 'README installer-facing publish path'; Text = $readme; Token = 'installer-facing publish path' },
    @{ Name = 'README local-vs-CI boundary'; Text = $readme; Token = 'local-vs-CI boundary' },
    @{ Name = 'README required checks'; Text = $readme; Token = 'ci-minimal / guardrails' },
    @{ Name = 'Surface registry readiness'; Text = $surface; Token = 'MCP_REGISTRY_READINESS.md' },
    @{ Name = 'Surface installer-facing guidance'; Text = $surface; Token = 'installer and registry readiness guidance' },
    @{ Name = 'Surface required checks'; Text = $surface; Token = 'ci-minimal / guardrails' },
    @{ Name = 'Release registry readiness'; Text = $release; Token = 'MCP_REGISTRY_READINESS.md' },
    @{ Name = 'Release installer-facing guide'; Text = $release; Token = 'installer-facing companion guide' },
    @{ Name = 'Release required checks'; Text = $release; Token = 'ci-diagnostics / diagnostics-focused' },
    @{ Name = 'Checklist registry readiness'; Text = $checklist; Token = 'registry-readiness rules' },
    @{ Name = 'Checklist installer-facing path'; Text = $checklist; Token = 'installer-facing usage path' },
    @{ Name = 'Readiness repo-relative'; Text = $readiness; Token = 'repo-relative' },
    @{ Name = 'Readiness no rooted path'; Text = $readiness; Token = 'Do not add local checkout paths' }
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
    @{ Name = 'EXECUTION_CHECKLIST'; Text = $checklist },
    @{ Name = 'MCP_REGISTRY_READINESS'; Text = $readiness }
)) {
    if ($item.Text -match $rootedPattern) {
        $rootedFindings += $item.Name
    }
}

$result = [pscustomobject]@{
    test = 'p3-registry-readiness-docs'
    pass = ($missing.Count -eq 0 -and $rootedFindings.Count -eq 0)
    missing = @($missing)
    rooted_findings = @($rootedFindings)
    exit_code = $(if ($missing.Count -eq 0 -and $rootedFindings.Count -eq 0) { 0 } else { 1 })
}

$result | ConvertTo-Json -Depth 4
exit $result.exit_code

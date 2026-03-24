param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\Invoke-DiagnosticsQuickCheck.ps1"

$scriptPath = Join-Path $PSScriptRoot 'check-release-package.ps1'
Assert-True (Test-Path $scriptPath) 'check-release-package.ps1 should exist'

$result = & $scriptPath

$diagArtifactPath = Join-Path ([System.IO.Path]::GetTempPath()) ("diagnostics-quickcheck-release-" + [System.Guid]::NewGuid().ToString("N") + ".json")
$diagSummary = Invoke-DiagnosticsQuickCheck -Quiet -OutputPath $diagArtifactPath

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
}

param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$scriptPath = Join-Path $PSScriptRoot 'check-release-package.ps1'
Assert-True (Test-Path $scriptPath) 'check-release-package.ps1 should exist'

$result = & $scriptPath

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
}

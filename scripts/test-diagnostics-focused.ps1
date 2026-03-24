param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\Invoke-DiagnosticsQuickCheck.ps1"

$summary = Invoke-DiagnosticsQuickCheck -Quiet

Assert-Equal $summary.pass $true "diagnostics focused checks should pass"

New-TestResult -Name "diagnostics-focused" -Data @{
    pass = $summary.pass
    exit_code = if ($summary.pass) { 0 } else { 1 }
    total = $summary.total
    passed = $summary.passed
    failed = $summary.failed
}

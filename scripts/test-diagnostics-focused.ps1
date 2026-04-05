param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\Invoke-DiagnosticsQuickCheck.ps1"

$summary = $null

if ($null -ne $Context -and $Context.ContainsKey('DiagnosticsQuickCheckSummary')) {
    $summary = $Context.DiagnosticsQuickCheckSummary
}
else {
    $outputPath = $null
    if ($null -ne $Context -and $Context.ContainsKey('DiagnosticsQuickCheckArtifactPath')) {
        $outputPath = [string]$Context.DiagnosticsQuickCheckArtifactPath
    }

    if ([string]::IsNullOrWhiteSpace($outputPath)) {
        $outputPath = Join-Path ([System.IO.Path]::GetTempPath()) ("diagnostics-quickcheck-shared-" + [System.Guid]::NewGuid().ToString("N") + ".json")
    }

    $summary = Invoke-DiagnosticsQuickCheck -Quiet -OutputPath $outputPath
    if ($null -ne $Context) {
        $Context.DiagnosticsQuickCheckSummary = $summary
        $Context.DiagnosticsQuickCheckArtifactPath = $outputPath
    }
}

Assert-Equal $summary.pass $true "diagnostics focused checks should pass"

New-TestResult -Name "diagnostics-focused" -Data @{
    pass = $summary.pass
    exit_code = if ($summary.pass) { 0 } else { 1 }
    total = $summary.total
    passed = $summary.passed
    failed = $summary.failed
}

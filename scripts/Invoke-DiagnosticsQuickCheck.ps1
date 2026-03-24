function Invoke-DiagnosticsQuickCheck {
    param(
        [switch]$Quiet,
        [string]$OutputPath
    )

    $repoRoot = Split-Path $PSScriptRoot -Parent
    $diagRoot = Join-Path $repoRoot 'diagnostics'
    $runner = 'powershell'

    $tests = @(
        'Test-RepairActionGuard.ps1',
        'Test-RepairActionExecutor-WxmlEncoding.ps1',
        'Test-CollectConsoleLog.ps1',
        'Test-ConsoleErrorOverlay.ps1',
        'Test-ConsoleErrorOverlay-NoiseWhitelist.ps1',
        'Test-AutomatorCheck.ps1',
        'Test-DetectorBridge-AutomatorPreferred.ps1',
        'Test-DetectorBridge.ps1',
        'Test-DetectorBridge-PreferredScreenshot.ps1',
        'Test-ProjectHealthOverlay-Encoding.ps1',
        'Test-DetectorRound.ps1',
        'Test-DetectorRound-JsonContract.ps1',
        'Test-RepairLoopDryRun.ps1',
        'Test-RepairLoopDryRun-HistoryContract.ps1',
        'Test-RepairLoopDryRun-Guardrails.ps1',
        'Test-RepairLoopDryRun-GuardBlocked.ps1',
        'Test-RepairLoopDryRun-JsonContract.ps1',
        'Test-RepairLoopAuto-Encoding.ps1',
        'screenshot\Test-ScreenshotFallback.ps1'
    )

    $results = @()
    foreach ($test in $tests) {
        $path = Join-Path $diagRoot $test
        $output = & $runner -ExecutionPolicy Bypass -File $path 2>&1 | Out-String
        $code = $LASTEXITCODE

        $results += [pscustomobject]@{
            test = $test
            pass = ($code -eq 0)
            exit_code = $code
            output = $output.Trim()
        }
    }

    $summary = [pscustomobject]@{
        pass = (@($results | Where-Object { -not $_.pass }).Count -eq 0)
        total = $results.Count
        passed = @($results | Where-Object { $_.pass }).Count
        failed = @($results | Where-Object { -not $_.pass }).Count
        results = $results
        timestamp = (Get-Date -Format 'o')
    }

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path $repoRoot 'artifacts\wechat-devtools\diagnostics\diagnostics-quickcheck-latest.json'
    }
    $outputDir = Split-Path $OutputPath -Parent
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    $summary | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputPath -Encoding UTF8

    if (-not $Quiet) {
        $summary | ConvertTo-Json -Depth 6
    }

    return $summary
}

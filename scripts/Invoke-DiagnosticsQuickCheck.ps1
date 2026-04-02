. "$PSScriptRoot\..\diagnostics\Write-DiagnosticsMetrics.ps1"

function Invoke-DiagnosticsQuickCheck {
    param(
        [switch]$Quiet,
        [string]$OutputPath
    )

    $repoRoot = Split-Path $PSScriptRoot -Parent
    $diagRoot = Join-Path $repoRoot 'diagnostics'
    $runner = 'powershell'
    $runnerArgs = @(
        '-NoProfile',
        '-NonInteractive',
        '-ExecutionPolicy', 'Bypass',
        '-File'
    )

    $tests = @(
        'Test-RepairActionGuard.ps1',
        'Test-RepairActionExecutor-WxmlEncoding.ps1',
        'Test-RepairActionExecutor-RouteFixes.ps1',
        'Test-RepairActionExecutor-MissingNavigationBar.ps1',
        'Test-RepairActionExecutor-MissingRequiredButton.ps1',
        'Test-RepairActionExecutor-RequiredTextMissing.ps1',
        'Test-RepairActionExecutor-RequiredTextMissingTextFallback.ps1',
        'Test-RepairActionExecutor-RequiredTextMissingShortTarget.ps1',
        'Test-RepairActionExecutor-EmptyListRenderEmptyState.ps1',
        'Test-RepairActionExecutor-EmptyListRenderTextFallback.ps1',
        'Test-RepairActionExecutor-EmptyListRenderShortTarget.ps1',
        'Test-RepairActionExecutor-ComponentRegistration.ps1',
        'Test-RepairActionExecutor-ComponentNotRenderedTextFallback.ps1',
        'Test-RepairActionExecutor-MissingRequiredElementTextFallback.ps1',
        'Test-RepairActionExecutor-UsingComponentsMismatch.ps1',
        'Test-RepairActionExecutor-BundleValidationFailed.ps1',
        'Test-RepairActionExecutor-WxmlCompileBlockers.ps1',
        'Test-RepairActionExecutor-DataNotBound.ps1',
        'Test-RepairActionExecutor-DataNotBoundShortTarget.ps1',
        'Test-RepairActionExecutor-DataNotBoundTextFallback.ps1',
        'Test-RepairActionExecutor-RouteRuntimeBlocker.ps1',
        'Test-RepairActionExecutor-PageJsonContract.ps1',
        'Test-MetricsSummaryDoc.ps1',
        'Test-CollectConsoleLog.ps1',
        'Test-ConsoleErrorOverlay.ps1',
        'Test-ConsoleErrorOverlay-NoiseWhitelist.ps1',
        '..\scripts\test-wechat-mcp-server-inventory.ps1',
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
        'screenshot\Test-OcrCheck-CompileText.ps1',
        'screenshot\Test-OcrCheck-RuntimeText.ps1',
        'screenshot\Test-OcrCheck-PassThrough.ps1',
        'screenshot\Test-ScreenshotFallback-OcrShortCircuit.ps1',
        'screenshot\Test-ScreenshotFallback.ps1'
    )

    function Get-TestFamily {
        param([string]$TestPath)

        if ($TestPath -like 'screenshot\*') {
            return 'screenshot'
        }

        $leaf = [System.IO.Path]::GetFileNameWithoutExtension($TestPath)
        $parts = $leaf -split '-'
        if ($parts.Count -ge 3 -and $parts[0] -eq 'Test') {
            return ($parts[0] + '-' + $parts[1])
        }

        if ($parts.Count -ge 2) {
            return ($parts[0] + '-' + $parts[1])
        }

        return $leaf
    }

    function Add-CountValue {
        param(
            [hashtable]$Map,
            [string]$Key,
            [int]$Amount = 1
        )

        $label = if ([string]::IsNullOrWhiteSpace($Key)) { 'unknown' } else { $Key }
        if (-not $Map.ContainsKey($label)) {
            $Map[$label] = 0
        }
        $Map[$label] = [int]$Map[$label] + [int]$Amount
    }

    $results = @()
    $familyCounts = @{}
    $testCounts = @{}
    $slowTests = @()
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $previousCaptureReuse = $env:WECHAT_CAPTURE_REUSE_WINDOW_MS
    $env:WECHAT_CAPTURE_REUSE_WINDOW_MS = '30000'
    try {
        foreach ($test in $tests) {
            $path = Join-Path $diagRoot $test
            $testStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $output = & $runner @runnerArgs $path 2>&1 | Out-String
            $code = $LASTEXITCODE
            $testStopwatch.Stop()
            $family = Get-TestFamily -TestPath $test

            Add-CountValue -Map $familyCounts -Key $family
            Add-CountValue -Map $testCounts -Key $test

            $result = [pscustomobject]@{
                test = $test
                pass = ($code -eq 0)
                exit_code = $code
                duration_ms = [int][Math]::Round($testStopwatch.Elapsed.TotalMilliseconds, 0)
                output = $output.Trim()
            }
            $results += $result
            $slowTests += $result
        }
    }
    finally {
        if ([string]::IsNullOrWhiteSpace($previousCaptureReuse)) {
            Remove-Item Env:WECHAT_CAPTURE_REUSE_WINDOW_MS -ErrorAction SilentlyContinue
        }
        else {
            $env:WECHAT_CAPTURE_REUSE_WINDOW_MS = $previousCaptureReuse
        }
    }
    $stopwatch.Stop()

    $summary = [pscustomobject]@{
        pass = (@($results | Where-Object { -not $_.pass }).Count -eq 0)
        total = $results.Count
        passed = @($results | Where-Object { $_.pass }).Count
        failed = @($results | Where-Object { -not $_.pass }).Count
        results = $results
        timestamp = (Get-Date -Format 'o')
    }

    $metrics = [pscustomobject]@{
        source = 'quickcheck'
        wall_clock_seconds = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        tests_total = [int]$summary.total
        tests_passed = [int]$summary.passed
        tests_failed = [int]$summary.failed
        test_family_counts = $familyCounts
        test_counts = $testCounts
        slow_tests = @(
            $slowTests |
                Sort-Object -Property duration_ms -Descending |
                Select-Object -First 5 |
                ForEach-Object {
                    [pscustomobject]@{
                        test = $_.test
                        duration_ms = $_.duration_ms
                        pass = $_.pass
                    }
                }
        )
        timestamp = (Get-Date -Format 'o')
    }

    Invoke-WriteDiagnosticsMetrics -Metrics $metrics | Out-Null

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

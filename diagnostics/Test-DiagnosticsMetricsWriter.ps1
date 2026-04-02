. "$PSScriptRoot\Write-DiagnosticsMetrics.ps1"

$root = Join-Path $env:TEMP ("diag-metrics-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root -Force | Out-Null

$path = Join-Path $root "latest-metrics.json"
$summaryPath = Join-Path $root "latest-metrics-summary.json"

$first = [pscustomobject]@{
  source = 'detector_round'
  detector_status = 'primary_passed'
  detector_status_counts = @{ primary_passed = 1 }
  issue_type_counts = @{ passed = 1 }
  issue_source_counts = @{ automator = 1 }
  decision_action_counts = @{ done = 1 }
}

$second = [pscustomobject]@{
  source = 'repair_loop_auto'
  final_status = 'success'
  repair_attempts_total = 2
  repair_applied_total = 1
  repair_blocked_total = 1
}

$third = [pscustomobject]@{
  source = 'quickcheck'
  wall_clock_seconds = 12.34
  tests_total = 4
  tests_passed = 3
  tests_failed = 1
  test_family_counts = @{ 'Test-DetectorBridge' = 2; screenshot = 1; 'Test-RepairActionExecutor' = 1 }
  test_counts = @{ 'Test-DetectorBridge.ps1' = 2; 'screenshot\Test-ScreenshotFallback.ps1' = 1; 'Test-RepairActionExecutor-RouteFixes.ps1' = 1 }
}

Invoke-WriteDiagnosticsMetrics -Metrics $first -OutputPath $path | Out-Null
Invoke-WriteDiagnosticsMetrics -Metrics $second -OutputPath $path | Out-Null
Invoke-WriteDiagnosticsMetrics -Metrics $third -OutputPath $path | Out-Null

$json = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$summaryJson = Get-Content -Path $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop

$pass = (
  [string]$json.schema_version -eq 'diagnostics_metrics_v1' -and
  [string]$json.source -eq 'quickcheck' -and
  [double]$json.metrics.wall_clock_seconds -eq 12.34 -and
  $json.metrics.tests_total -eq 4 -and
  $json.metrics.tests_passed -eq 3 -and
  $json.metrics.tests_failed -eq 1 -and
  $json.metrics.test_family_counts.'Test-DetectorBridge' -eq 2 -and
  $json.metrics.test_family_counts.screenshot -eq 1 -and
  $json.metrics.test_family_counts.'Test-RepairActionExecutor' -eq 1 -and
  $json.metrics.test_counts.'Test-DetectorBridge.ps1' -eq 2 -and
  $json.metrics.test_counts.'screenshot\Test-ScreenshotFallback.ps1' -eq 1 -and
  $json.metrics.test_counts.'Test-RepairActionExecutor-RouteFixes.ps1' -eq 1 -and
  [string]$summaryJson.schema_version -eq 'diagnostics_metrics_summary_v1' -and
  $summaryJson.detector_runs_total -eq 1 -and
  $summaryJson.repair_runs_total -eq 1 -and
  $summaryJson.repair_attempts_total -eq 2 -and
  $summaryJson.repair_applied_total -eq 1 -and
  $summaryJson.repair_blocked_total -eq 1 -and
  $summaryJson.issue_type_counts.passed -eq 1 -and
  $summaryJson.issue_source_counts.automator -eq 1 -and
  $summaryJson.decision_action_counts.done -eq 1 -and
  $summaryJson.final_status_counts.success -eq 1 -and
  $summaryJson.quickcheck_runs_total -eq 1 -and
  [math]::Abs([double]$summaryJson.quickcheck_wall_clock_seconds_total - 12.34) -lt 0.0001 -and
  [math]::Abs([double]$summaryJson.quickcheck_average_wall_clock_seconds - 12.34) -lt 0.0001 -and
  [string]$summaryJson.operator_focus -eq 'repair_coverage' -and
  [string]$summaryJson.operator_focus_reason -match 'repair blocked' -and
  ($summaryJson.operator_next_actions -join '; ') -match 'expand deterministic repair coverage for narrow runtime or data blockers' -and
  ($summaryJson.operator_next_actions -join '; ') -match 'avoid broad UI guessing and keep selector targets explicit' -and
  $summaryJson.quickcheck_tests_total -eq 4 -and
  $summaryJson.quickcheck_passed_total -eq 3 -and
  $summaryJson.quickcheck_failed_total -eq 1 -and
  $summaryJson.quickcheck_family_counts.'Test-DetectorBridge' -eq 2 -and
  $summaryJson.quickcheck_family_counts.screenshot -eq 1 -and
  $summaryJson.quickcheck_family_counts.'Test-RepairActionExecutor' -eq 1 -and
  $summaryJson.quickcheck_test_counts.'Test-DetectorBridge.ps1' -eq 2 -and
  $summaryJson.quickcheck_test_counts.'screenshot\Test-ScreenshotFallback.ps1' -eq 1 -and
  $summaryJson.quickcheck_test_counts.'Test-RepairActionExecutor-RouteFixes.ps1' -eq 1 -and
  [string]::IsNullOrWhiteSpace([string]$summaryJson.public_summary) -eq $false -and
  ([string]$summaryJson.public_summary) -notmatch 'C:\\Users|AppData|Temp' -and
  ([string]$summaryJson.public_summary) -notmatch 'project-scoped port|local machine' -and
  [string]::IsNullOrWhiteSpace([string]$summaryJson.operator_task_hint) -eq $false -and
  ([string]$summaryJson.operator_task_hint) -notmatch 'C:\\Users|AppData|Temp' -and
  [string]::IsNullOrWhiteSpace([string]$summaryJson.operator_priority_action) -eq $false -and
  ([string]$summaryJson.operator_priority_action) -notmatch 'C:\\Users|AppData|Temp' -and
  [string]$summaryJson.operator_priority_level -eq 'high' -and
  [string]$summaryJson.next_step_category -eq 'expand_repair_coverage' -and
  [string]$summaryJson.operator_snapshot.focus -eq [string]$summaryJson.operator_focus -and
  [string]$summaryJson.operator_snapshot.reason -eq [string]$summaryJson.operator_focus_reason -and
  [string]$summaryJson.operator_snapshot.public_summary -eq [string]$summaryJson.public_summary -and
  [string]$summaryJson.operator_snapshot.next_step_category -eq [string]$summaryJson.next_step_category -and
  [string]$summaryJson.operator_snapshot.priority_action -eq [string]$summaryJson.operator_priority_action -and
  [string]$summaryJson.operator_snapshot.priority_level -eq [string]$summaryJson.operator_priority_level -and
  [string]$summaryJson.operator_snapshot.task_hint -eq [string]$summaryJson.operator_task_hint -and
  [string]$summaryJson.operator_snapshot.trend.state -eq [string]$summaryJson.trend_state -and
  [string]$summaryJson.operator_snapshot.trend.reason -eq [string]$summaryJson.trend_state_reason -and
  [string]$summaryJson.operator_snapshot.trend.digest -eq [string]$summaryJson.trend_digest -and
  [string]$summaryJson.operator_snapshot.trend.breakdown.top_issue_family -eq [string]$summaryJson.trend_breakdown.top_issue_family -and
  [string]$summaryJson.operator_snapshot.trend.breakdown.top_quickcheck_family -eq [string]$summaryJson.trend_breakdown.top_quickcheck_family
)

$summary = [pscustomobject]@{
  test = 'diagnostics-metrics-writer'
  pass = $pass
  exit_code = $(if ($pass) { 0 } else { 1 })
  path = $path
  summary_path = $summaryPath
  schema_version = [string]$json.schema_version
  source = [string]$json.source
}

$summary | ConvertTo-Json -Depth 6

$fallbackRoot = Join-Path $env:TEMP ("diag-metrics-fallback-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $fallbackRoot -Force | Out-Null

$fallbackPath = Join-Path $fallbackRoot "latest-metrics.json"
$fallbackSummaryPath = Join-Path $fallbackRoot "latest-metrics-summary.json"
Set-Content -Path $fallbackSummaryPath -Value "not-json" -Encoding UTF8

$fallbackMetrics = [pscustomobject]@{
  source = 'quickcheck'
  wall_clock_seconds = 1.5
  tests_total = 1
  tests_passed = 1
  tests_failed = 0
  test_family_counts = @{ smoke = 1 }
  test_counts = @{ 'smoke\Test-One.ps1' = 1 }
}

Invoke-WriteDiagnosticsMetrics -Metrics $fallbackMetrics -OutputPath $fallbackPath | Out-Null

$fallbackJson = Get-Content -Path $fallbackPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$fallbackSummaryJson = Get-Content -Path $fallbackSummaryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop

$fallbackPass = (
  [string]$fallbackJson.source -eq 'quickcheck' -and
  [string]$fallbackSummaryJson.schema_version -eq 'diagnostics_metrics_summary_v1' -and
  $fallbackSummaryJson.quickcheck_runs_total -eq 1 -and
  [math]::Abs([double]$fallbackSummaryJson.quickcheck_wall_clock_seconds_total - 1.5) -lt 0.0001 -and
  [string]$fallbackSummaryJson.operator_focus -eq 'steady_state' -and
  [string]$fallbackSummaryJson.operator_focus_reason -match 'no dominant blocker' -and
  ($fallbackSummaryJson.operator_next_actions -join '; ') -match 'keep current guardrails stable' -and
  ($fallbackSummaryJson.operator_next_actions -join '; ') -match 'watch trend breakdown for regressions' -and
  $fallbackSummaryJson.quickcheck_tests_total -eq 1 -and
  $fallbackSummaryJson.quickcheck_passed_total -eq 1 -and
  $fallbackSummaryJson.quickcheck_failed_total -eq 0 -and
  $fallbackSummaryJson.quickcheck_family_counts.smoke -eq 1 -and
  $fallbackSummaryJson.quickcheck_test_counts.'smoke\Test-One.ps1' -eq 1 -and
  [string]::IsNullOrWhiteSpace([string]$fallbackSummaryJson.public_summary) -eq $false -and
  ([string]$fallbackSummaryJson.public_summary) -notmatch 'C:\\Users|AppData|Temp' -and
  ([string]$fallbackSummaryJson.public_summary) -notmatch 'project-scoped port|local machine' -and
  [string]::IsNullOrWhiteSpace([string]$fallbackSummaryJson.operator_task_hint) -eq $false -and
  ([string]$fallbackSummaryJson.operator_task_hint) -notmatch 'C:\\Users|AppData|Temp' -and
  [string]::IsNullOrWhiteSpace([string]$fallbackSummaryJson.operator_priority_action) -eq $false -and
  ([string]$fallbackSummaryJson.operator_priority_action) -notmatch 'C:\\Users|AppData|Temp' -and
  [string]$fallbackSummaryJson.operator_priority_level -eq 'normal' -and
  [string]$fallbackSummaryJson.next_step_category -eq 'maintain_and_watch' -and
  [string]$fallbackSummaryJson.operator_snapshot.focus -eq [string]$fallbackSummaryJson.operator_focus -and
  [string]$fallbackSummaryJson.operator_snapshot.public_summary -eq [string]$fallbackSummaryJson.public_summary -and
  [string]$fallbackSummaryJson.operator_snapshot.next_step_category -eq [string]$fallbackSummaryJson.next_step_category -and
  [string]$fallbackSummaryJson.operator_snapshot.priority_action -eq [string]$fallbackSummaryJson.operator_priority_action -and
  [string]$fallbackSummaryJson.operator_snapshot.priority_level -eq [string]$fallbackSummaryJson.operator_priority_level -and
  [string]$fallbackSummaryJson.operator_snapshot.task_hint -eq [string]$fallbackSummaryJson.operator_task_hint -and
  [string]$fallbackSummaryJson.operator_snapshot.trend.state -eq [string]$fallbackSummaryJson.trend_state
)

if (-not $fallbackPass) {
  Write-Host '[test] FAIL: summary fallback coverage failed' -ForegroundColor Red
  exit 1
}

Write-Host '[test] PASS: summary fallback coverage verified' -ForegroundColor Green
exit $summary.exit_code

param()

. "$PSScriptRoot\..\diagnostics\Write-DiagnosticsMetrics.ps1"
. "$PSScriptRoot\get-diagnostics-metrics-summary.ps1"

$missingPath = Join-Path $env:TEMP ("diag-metrics-missing-" + [guid]::NewGuid().ToString("N") + ".json")
$result = Get-DiagnosticsMetricsSummary -Path $missingPath

$pass = (
  [string]$result.status -eq 'missing' -and
  [string]$result.path -eq $missingPath -and
  [string]$result.schema_version -eq 'diagnostics_metrics_summary_v1' -and
  [int]$result.detector_runs_total -eq 0 -and
  [int]$result.repair_runs_total -eq 0 -and
  [double]$result.repair_success_rate -eq 0 -and
  [int]$result.quickcheck_runs_total -eq 0 -and
  [string]$result.operator_focus -eq 'insufficient_data' -and
  [string]$result.operator_focus_reason -match 'unavailable' -and
  [string]::IsNullOrWhiteSpace([string]$result.public_summary) -eq $false -and
  ([string]$result.public_summary) -notmatch 'C:\\Users|AppData|Temp' -and
  [string]::IsNullOrWhiteSpace([string]$result.operator_task_hint) -eq $false -and
  ([string]$result.operator_task_hint) -notmatch 'C:\\Users|AppData|Temp' -and
  [string]::IsNullOrWhiteSpace([string]$result.operator_priority_action) -eq $false -and
  ([string]$result.operator_priority_action) -notmatch 'C:\\Users|AppData|Temp' -and
  [string]$result.operator_priority_level -eq 'needs_data' -and
  [string]$result.next_step_category -eq 'collect_more_data' -and
  [string]$result.operator_snapshot.focus -eq [string]$result.operator_focus -and
  [string]$result.operator_snapshot.public_summary -eq [string]$result.public_summary -and
  [string]$result.operator_snapshot.next_step_category -eq [string]$result.next_step_category -and
  [string]$result.operator_snapshot.priority_action -eq [string]$result.operator_priority_action -and
  [string]$result.operator_snapshot.priority_level -eq [string]$result.operator_priority_level -and
  [string]$result.operator_snapshot.task_hint -eq [string]$result.operator_task_hint -and
  [string]$result.operator_snapshot.trend.state -eq [string]$result.trend_state -and
  [string]$result.trend_state -eq 'insufficient_data' -and
  [string]$result.trend_state_reason -match 'unavailable' -and
  [string]$result.trend_digest -match 'unavailable' -and
  [string]$result.trend_breakdown.detector.runs -eq '0' -and
  [string]$result.trend_breakdown.repair.success_rate -eq '0' -and
  [string]$result.trend_breakdown.quickcheck.pass_rate -eq '0' -and
  [string]$result.trend_breakdown.top_issue_family -eq 'none' -and
  [string]$result.trend_breakdown.top_quickcheck_family -eq 'none'
)

$sampleRoot = Join-Path $env:TEMP ("diag-metrics-summary-sample-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $sampleRoot -Force | Out-Null

$samplePath = Join-Path $sampleRoot 'latest-metrics.json'

$detector = [pscustomobject]@{
  source = 'detector_round'
  detector_status = 'primary_failed_fallback_used'
  issue_type_counts = @{ page_blank = 2; missing_required_element = 1 }
  issue_source_counts = @{ screenshot = 2; automator = 1 }
  decision_action_counts = @{ retry = 2; done = 1 }
}

$repair = [pscustomobject]@{
  source = 'repair_loop_auto'
  final_status = 'success'
  repair_attempts_total = 3
  repair_applied_total = 2
  repair_blocked_total = 1
}

$quickcheck = [pscustomobject]@{
  source = 'quickcheck'
  wall_clock_seconds = 9.5
  tests_total = 5
  tests_passed = 5
  tests_failed = 0
  test_family_counts = @{ 'Test-DetectorBridge' = 3; 'Test-RepairActionExecutor' = 2 }
  test_counts = @{ 'Test-DetectorBridge.ps1' = 3; 'Test-RepairActionExecutor-RouteFixes.ps1' = 2 }
}

Invoke-WriteDiagnosticsMetrics -Metrics $detector -OutputPath $samplePath | Out-Null
Invoke-WriteDiagnosticsMetrics -Metrics $repair -OutputPath $samplePath | Out-Null
Invoke-WriteDiagnosticsMetrics -Metrics $quickcheck -OutputPath $samplePath | Out-Null

$sampleResult = Get-DiagnosticsMetricsSummary -Path (Join-Path $sampleRoot 'latest-metrics-summary.json')

$samplePass = (
  [string]$sampleResult.status -eq 'ok' -and
  [string]$sampleResult.schema_version -eq 'diagnostics_metrics_summary_v1' -and
  [string]$sampleResult.operator_focus -eq 'detector_stability' -and
  [string]$sampleResult.operator_focus_reason -match 'detector fallback used' -and
  [string]::IsNullOrWhiteSpace([string]$sampleResult.public_summary) -eq $false -and
  ([string]$sampleResult.public_summary) -notmatch 'C:\\Users|AppData|Temp' -and
  [string]::IsNullOrWhiteSpace([string]$sampleResult.operator_task_hint) -eq $false -and
  ([string]$sampleResult.operator_task_hint) -notmatch 'C:\\Users|AppData|Temp' -and
  [string]::IsNullOrWhiteSpace([string]$sampleResult.operator_priority_action) -eq $false -and
  ([string]$sampleResult.operator_priority_action) -notmatch 'C:\\Users|AppData|Temp' -and
  [string]$sampleResult.operator_priority_level -eq 'high' -and
  [string]$sampleResult.next_step_category -eq 'stabilize_detection' -and
  [string]$sampleResult.operator_snapshot.focus -eq [string]$sampleResult.operator_focus -and
  [string]$sampleResult.operator_snapshot.reason -eq [string]$sampleResult.operator_focus_reason -and
  [string]$sampleResult.operator_snapshot.public_summary -eq [string]$sampleResult.public_summary -and
  [string]$sampleResult.operator_snapshot.next_step_category -eq [string]$sampleResult.next_step_category -and
  [string]$sampleResult.operator_snapshot.priority_action -eq [string]$sampleResult.operator_priority_action -and
  [string]$sampleResult.operator_snapshot.priority_level -eq [string]$sampleResult.operator_priority_level -and
  [string]$sampleResult.operator_snapshot.task_hint -eq [string]$sampleResult.operator_task_hint -and
  [string]$sampleResult.operator_snapshot.trend.state -eq [string]$sampleResult.trend_state -and
  [string]$sampleResult.operator_snapshot.trend.reason -eq [string]$sampleResult.trend_state_reason -and
  [string]$sampleResult.trend_state -eq 'attention' -and
  [string]$sampleResult.trend_state_reason -match 'follow-up' -and
  [string]$sampleResult.trend_digest -match 'detector=1' -and
  [string]$sampleResult.trend_digest -match 'fallback=1' -and
  [string]$sampleResult.trend_digest -match 'repair=1' -and
  [string]$sampleResult.trend_digest -match 'quickcheck=1' -and
  [string]$sampleResult.trend_digest -match 'focus=detector_stability' -and
  [string]$sampleResult.trend_digest -match 'topIssues=' -and
  [string]$sampleResult.trend_digest -match 'topFamilies=' -and
  [int]$sampleResult.trend_breakdown.detector.runs -eq 1 -and
  [int]$sampleResult.trend_breakdown.detector.fallback_used -eq 1 -and
  [double]$sampleResult.trend_breakdown.detector.fallback_rate -eq 100 -and
  [int]$sampleResult.trend_breakdown.repair.runs -eq 1 -and
  [double]$sampleResult.trend_breakdown.repair.success_rate -eq 100 -and
  [int]$sampleResult.trend_breakdown.quickcheck.runs -eq 1 -and
  [double]$sampleResult.trend_breakdown.quickcheck.pass_rate -eq 100 -and
  [string]$sampleResult.trend_breakdown.top_issue_family -eq 'page_blank' -and
  [string]$sampleResult.trend_breakdown.top_quickcheck_family -eq 'Test-DetectorBridge' -and
  [string]$sampleResult.trend_breakdown.operator_focus -eq 'detector_stability' -and
  [string]$sampleResult.trend_breakdown.operator_focus_reason -match 'detector fallback used' -and
  $sampleResult.top_issue_types.Count -ge 1 -and
  [string]$sampleResult.top_issue_types[0].name -eq 'page_blank' -and
  ([string]$sampleResult.public_summary) -notmatch 'project-scoped port|local machine' -and
  [string]$sampleResult.operator_snapshot.trend.digest -eq [string]$sampleResult.trend_digest -and
  [string]$sampleResult.operator_snapshot.trend.breakdown.top_issue_family -eq [string]$sampleResult.trend_breakdown.top_issue_family
)

if (Test-Path $sampleRoot) {
  Remove-Item -LiteralPath $sampleRoot -Recurse -Force -ErrorAction SilentlyContinue
}

$pass = $pass -and $samplePass

[pscustomobject]@{
  test = 'diagnostics-metrics-summary-command'
  pass = $pass
  exit_code = $(if ($pass) { 0 } else { 1 })
  status = [string]$result.status
  schema_version = [string]$result.schema_version
  trend_digest = [string]$result.trend_digest
  operator_focus = [string]$result.operator_focus
  operator_focus_reason = [string]$result.operator_focus_reason
  public_summary = [string]$result.public_summary
  operator_task_hint = [string]$result.operator_task_hint
  operator_priority_action = [string]$result.operator_priority_action
  operator_priority_level = [string]$result.operator_priority_level
  next_step_category = [string]$result.next_step_category
  operator_snapshot = $result.operator_snapshot
  trend_state = [string]$result.trend_state
  trend_state_reason = [string]$result.trend_state_reason
  operator_next_actions = $result.operator_next_actions
  sample_pass = $samplePass
} | ConvertTo-Json -Depth 4

exit $(if ($pass) { 0 } else { 1 })

param()

$docPath = Join-Path $PSScriptRoot 'METRICS_SUMMARY.md'

if (-not (Test-Path $docPath)) {
  Write-Host '[test] FAIL: METRICS_SUMMARY.md is missing' -ForegroundColor Red
  exit 1
}

$content = Get-Content -Path $docPath -Raw -Encoding UTF8

$requiredTokens = @(
  'latest-metrics-summary.json',
  'detector_runs_total',
  'quickcheck_average_wall_clock_seconds',
  'repair_attempts_total',
  'issue_type_counts',
  'operator_focus',
  'operator_focus_reason',
  'operator_next_actions',
  'operator_task_hint',
  'operator_priority_action',
  'operator_priority_level',
  'next_step_category',
  'public_summary',
  'operator_snapshot',
  'machine-neutral'
)

$missing = @($requiredTokens | Where-Object { $content -notmatch [regex]::Escape($_) })

if ($missing.Count -gt 0) {
  Write-Host "[test] FAIL: missing tokens: $($missing -join ', ')" -ForegroundColor Red
  exit 1
}

Write-Host '[test] PASS: metrics summary doc contract is readable' -ForegroundColor Green
exit 0

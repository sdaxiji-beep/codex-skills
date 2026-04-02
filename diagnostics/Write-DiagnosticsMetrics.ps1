function Invoke-WriteDiagnosticsMetrics {
  param(
    [Parameter(Mandatory = $true)]$Metrics,
    [string]$OutputPath
  )

  $repoRoot = Split-Path $PSScriptRoot -Parent
  if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot 'artifacts\wechat-devtools\diagnostics\latest-metrics.json'
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

  function Merge-CountMap {
    param(
      [hashtable]$Destination,
      $SourceMap
    )

    if ($null -eq $SourceMap) {
      return
    }

    if ($SourceMap -is [System.Collections.IDictionary]) {
      foreach ($key in $SourceMap.Keys) {
        Add-CountValue -Map $Destination -Key ([string]$key) -Amount ([int]$SourceMap[$key])
      }
      return
    }

    foreach ($prop in $SourceMap.PSObject.Properties) {
      if ($prop.MemberType -ne 'NoteProperty' -and $prop.MemberType -ne 'Property') {
        continue
      }
      Add-CountValue -Map $Destination -Key ([string]$prop.Name) -Amount ([int]$prop.Value)
    }
  }

  function Get-TopCountEntries {
    param(
      [object]$Counts,
      [int]$Limit = 3
    )

    if ($null -eq $Counts) {
      return @()
    }

    $entries = @()

    if ($Counts -is [System.Collections.IDictionary]) {
      foreach ($key in $Counts.Keys) {
        $entries += [pscustomobject]@{
          name = [string]$key
          count = [int]$Counts[$key]
        }
      }
    }
    else {
      foreach ($prop in $Counts.PSObject.Properties) {
        if ($prop.MemberType -ne 'NoteProperty' -and $prop.MemberType -ne 'Property') {
          continue
        }
        $entries += [pscustomobject]@{
          name = [string]$prop.Name
          count = [int]$prop.Value
        }
      }
    }

    return @(
      $entries |
        Sort-Object @{ Expression = 'count'; Descending = $true }, @{ Expression = 'name'; Descending = $false } |
        Select-Object -First $Limit
    )
  }

  function Get-TopEntryName {
    param([object[]]$Entries)

    if (-not $Entries -or $Entries.Count -eq 0) {
      return 'none'
    }

    return [string]$Entries[0].name
  }

  function Format-CountEntries {
    param([object[]]$Entries)

    if (-not $Entries -or $Entries.Count -eq 0) {
      return 'none'
    }

    return ($Entries | ForEach-Object { "$($_.name)=$($_.count)" }) -join ', '
  }

  function Get-Percent {
    param(
      [double]$Numerator,
      [double]$Denominator
    )

    if ($Denominator -le 0) {
      return 0
    }

    return [Math]::Round(($Numerator / $Denominator) * 100, 2)
  }

  function Get-OperatorFocus {
    param([hashtable]$Summary)

    $quickcheckRuns = [int]$Summary.quickcheck_runs_total
    $quickcheckAverage = [double]$Summary.quickcheck_average_wall_clock_seconds
    $detectorFallback = [int]$Summary.detector_fallback_used_total
    $repairBlocked = [int]$Summary.repair_blocked_total
    $repairAttempts = [int]$Summary.repair_attempts_total

    if ($quickcheckRuns -gt 0 -and $quickcheckAverage -ge 90) {
      return [pscustomobject]@{
        focus = 'fast_path_fixture_reduction'
        reason = "quickcheck average wall clock is $quickcheckAverage seconds"
      }
    }

    if ($detectorFallback -gt 0) {
      return [pscustomobject]@{
        focus = 'detector_stability'
        reason = "detector fallback used $detectorFallback time(s)"
      }
    }

    if ($repairBlocked -gt 0) {
      return [pscustomobject]@{
        focus = 'repair_coverage'
        reason = "repair blocked $repairBlocked of $repairAttempts attempt(s)"
      }
    }

    if ($quickcheckRuns -gt 0) {
      return [pscustomobject]@{
        focus = 'steady_state'
        reason = "quickcheck average wall clock is $quickcheckAverage seconds and no dominant blocker remains"
      }
    }

    return [pscustomobject]@{
      focus = 'insufficient_data'
      reason = 'no detector, repair, or quickcheck samples yet'
    }
  }

  function Get-OperatorNextActions {
    param([string]$OperatorFocus)

    switch ($OperatorFocus) {
      'fast_path_fixture_reduction' {
        return @(
          'merge repeated fast-path fixtures',
          'separate heavy doctor and get-port setup from shared quickcheck paths'
        )
      }
      'detector_stability' {
        return @(
          'review automator fallback and project-scoped port selection',
          'reduce stale session reuse before widening detector coverage'
        )
      }
      'repair_coverage' {
        return @(
          'expand deterministic repair coverage for narrow runtime or data blockers',
          'avoid broad UI guessing and keep selector targets explicit'
        )
      }
      'steady_state' {
        return @(
          'keep current guardrails stable',
          'watch trend breakdown for regressions'
        )
      }
      default {
        return @(
          'collect more detector, repair, and quickcheck samples'
        )
      }
    }
  }

  function Get-OperatorTaskHint {
    param(
      [string]$OperatorFocus,
      [string]$NextStepCategory
    )

    switch ($OperatorFocus) {
      'fast_path_fixture_reduction' {
        return 'If the goal is faster validation, start with shared fixture reuse and repeated fast-path setup reduction.'
      }
      'detector_stability' {
        return 'If the goal is more reliable inspection, start with detector fallback and stale-session reuse reduction.'
      }
      'repair_coverage' {
        return 'If the goal is more automatic fixes, start with narrow deterministic repair expansion.'
      }
      'steady_state' {
        return 'If the goal is steady operation, keep the current guardrails and watch the trend breakdown.'
      }
      default {
        if ($NextStepCategory -eq 'collect_more_data') {
          return 'If the goal is to decide the next move, collect more detector, repair, and quickcheck samples first.'
        }
        return 'If the goal is to continue, follow the next-step category and keep the public surface stable.'
      }
    }
  }

  function Get-OperatorPriorityAction {
    param([object[]]$OperatorNextActions)

    if (-not $OperatorNextActions -or $OperatorNextActions.Count -eq 0) {
      return 'collect more detector, repair, and quickcheck samples'
    }

    return [string]$OperatorNextActions[0]
  }

  function Get-OperatorPriorityLevel {
    param(
      [string]$OperatorFocus,
      [string]$TrendState
    )

    switch ($OperatorFocus) {
      'fast_path_fixture_reduction' { return 'high' }
      'detector_stability' { return 'high' }
      'repair_coverage' { return 'high' }
      'steady_state' { return 'normal' }
      default {
        if ($TrendState -eq 'insufficient_data') {
          return 'needs_data'
        }
        return 'normal'
      }
    }
  }

  function Get-NextStepCategory {
    param(
      [string]$OperatorFocus,
      [string]$TrendState
    )

    switch ($OperatorFocus) {
      'fast_path_fixture_reduction' { return 'optimize_test_fixtures' }
      'detector_stability' { return 'stabilize_detection' }
      'repair_coverage' { return 'expand_repair_coverage' }
      'steady_state' { return 'maintain_and_watch' }
      default {
        if ($TrendState -eq 'insufficient_data') {
          return 'collect_more_data'
        }
        return 'general_follow_up'
      }
    }
  }

  function Get-PublicSummary {
    param([string]$OperatorFocus)

    switch ($OperatorFocus) {
      'fast_path_fixture_reduction' {
        return 'Fast-path fixture reduction remains the active optimization area.'
      }
      'detector_stability' {
        return 'Detector stability needs follow-up; reduce fallback and stale-session reuse.'
      }
      'repair_coverage' {
        return 'Repair coverage needs follow-up; keep repairs narrow and deterministic.'
      }
      'steady_state' {
        return 'Metrics are in steady state; keep guardrails stable and watch trend breakdowns.'
      }
      default {
        return 'No metrics samples yet; collect detector, repair, and quickcheck runs.'
      }
    }
  }

  function Get-TrendState {
    param([string]$OperatorFocus)

    switch ($OperatorFocus) {
      'steady_state' {
        return [pscustomobject]@{
          state = 'steady'
          reason = 'no dominant blocker remains'
        }
      }
      'insufficient_data' {
        return [pscustomobject]@{
          state = 'insufficient_data'
          reason = 'metrics summary unavailable'
        }
      }
      default {
        return [pscustomobject]@{
          state = 'attention'
          reason = 'operator focus requires active follow-up'
        }
      }
    }
  }

  function Get-TrendDigest {
    param(
      [hashtable]$Summary,
      [int]$RepairRuns,
      [double]$RepairSuccessRate,
      [string]$OperatorFocus,
      [string]$TopIssueFamilies,
      [string]$TopQuickcheckFamilies,
      [int]$DetectorRuns,
      [int]$DetectorFallback,
      [int]$QuickcheckRuns,
      [int]$QuickcheckTests,
      [double]$QuickcheckAverage
    )

    $parts = @()

    $detectorPart = "detector=$DetectorRuns"
    if ($DetectorFallback -gt 0) {
      $detectorPart += ", fallback=$DetectorFallback"
    }
    $parts += $detectorPart

    $repairPart = "repair=$RepairRuns"
    if ($RepairRuns -gt 0) {
      $repairPart += ", success=$RepairSuccessRate%"
      $repairPart += ", avgRounds=$([double]$Summary.average_completed_rounds)"
    }
    $parts += $repairPart

    $quickcheckPart = "quickcheck=$QuickcheckRuns"
    if ($QuickcheckRuns -gt 0) {
      $quickcheckPart += ", tests=$QuickcheckTests"
      $quickcheckPart += ", avgSeconds=$QuickcheckAverage"
    }
    $parts += $quickcheckPart

    $parts += "topIssues=$TopIssueFamilies"
    $parts += "topFamilies=$TopQuickcheckFamilies"
    $parts += "focus=$OperatorFocus"

    return ($parts -join '; ')
  }

  function Get-OperatorSnapshot {
    param(
      [string]$OperatorFocus,
      [string]$OperatorFocusReason,
      [object[]]$OperatorNextActions,
      [string]$NextStepCategory,
      [string]$OperatorPriorityAction,
      [string]$OperatorPriorityLevel,
      [string]$OperatorTaskHint,
      [string]$PublicSummary,
      [string]$TrendState,
      [string]$TrendStateReason,
      [string]$TrendDigest,
      [object]$TrendBreakdown
    )

    return [pscustomobject]@{
      focus = $OperatorFocus
      reason = $OperatorFocusReason
      next_actions = $OperatorNextActions
      next_step_category = $NextStepCategory
      priority_action = $OperatorPriorityAction
      priority_level = $OperatorPriorityLevel
      task_hint = $OperatorTaskHint
      public_summary = $PublicSummary
      trend = [pscustomobject]@{
        state = $TrendState
        reason = $TrendStateReason
        digest = $TrendDigest
        breakdown = $TrendBreakdown
      }
    }
  }

  function Write-JsonAtomically {
    param(
      [Parameter(Mandatory = $true)][string]$Path,
      [Parameter(Mandatory = $true)][string]$Json
    )

    $dir = Split-Path $Path -Parent
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $tempPath = Join-Path $dir ('.' + [guid]::NewGuid().ToString('N') + '.tmp')
    $encoding = New-Object System.Text.UTF8Encoding($false)

    try {
      [System.IO.File]::WriteAllText($tempPath, $Json, $encoding)
      if (Test-Path $Path) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
      }
      Move-Item -LiteralPath $tempPath -Destination $Path -Force
    }
    finally {
      if (Test-Path $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
      }
    }
  }

  $outputDir = Split-Path $OutputPath -Parent
  New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

  $payload = [pscustomobject]@{
    schema_version = 'diagnostics_metrics_v1'
    generated_at = (Get-Date -Format 'o')
    source = if ($Metrics.PSObject.Properties.Name -contains 'source') { [string]$Metrics.source } else { 'unknown' }
    metrics = $Metrics
  }
  $json = $payload | ConvertTo-Json -Depth 20
  Write-JsonAtomically -Path $OutputPath -Json $json

  $summaryPath = Join-Path $outputDir 'latest-metrics-summary.json'
  $summary = [ordered]@{
    schema_version = 'diagnostics_metrics_summary_v1'
    generated_at = (Get-Date -Format 'o')
    last_source = $payload.source
    detector_runs_total = 0
    detector_fallback_used_total = 0
    issue_type_counts = @{}
    issue_source_counts = @{}
    decision_action_counts = @{}
    quickcheck_runs_total = 0
    quickcheck_wall_clock_seconds_total = 0
    quickcheck_average_wall_clock_seconds = 0
    quickcheck_tests_total = 0
    quickcheck_passed_total = 0
    quickcheck_failed_total = 0
    quickcheck_family_counts = @{}
    quickcheck_test_counts = @{}
    repair_attempts_total = 0
    repair_applied_total = 0
    repair_blocked_total = 0
    repair_success_runs_total = 0
    completed_rounds_total = 0
    repair_runs_total = 0
    average_completed_rounds = 0
    final_status_counts = @{}
    operator_focus = 'insufficient_data'
    operator_focus_reason = 'summary not generated yet'
    operator_next_actions = @('collect more detector, repair, and quickcheck samples')
    operator_priority_level = 'needs_data'
    public_summary = 'No metrics samples yet; collect detector, repair, and quickcheck runs.'
    operator_snapshot = [pscustomobject]@{
      focus = 'insufficient_data'
      reason = 'summary not generated yet'
      next_actions = @('collect more detector, repair, and quickcheck samples')
      priority_level = 'needs_data'
      public_summary = 'No metrics samples yet; collect detector, repair, and quickcheck runs.'
      trend = [pscustomobject]@{
        state = 'insufficient_data'
        reason = 'metrics summary unavailable'
        digest = 'metrics summary unavailable'
        breakdown = [pscustomobject]@{
          detector = [pscustomobject]@{ runs = 0; fallback_used = 0; fallback_rate = 0 }
          repair = [pscustomobject]@{ runs = 0; success_runs = 0; success_rate = 0; average_completed_rounds = 0 }
          quickcheck = [pscustomobject]@{ runs = 0; tests_total = 0; pass_rate = 0; average_wall_clock_seconds = 0 }
          top_issue_family = 'none'
          top_quickcheck_family = 'none'
          operator_focus = 'insufficient_data'
          operator_focus_reason = 'metrics summary unavailable'
          operator_next_actions = @('collect more detector, repair, and quickcheck samples')
        }
      }
    }
  }

  if (Test-Path $summaryPath) {
    try {
      $existing = Get-Content -Path $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
      $summary.schema_version = [string]$existing.schema_version
      $summary.detector_runs_total = [int]$existing.detector_runs_total
      $summary.detector_fallback_used_total = [int]$existing.detector_fallback_used_total
      $summary.repair_attempts_total = [int]$existing.repair_attempts_total
      $summary.repair_applied_total = [int]$existing.repair_applied_total
      $summary.repair_blocked_total = [int]$existing.repair_blocked_total
      $summary.repair_success_runs_total = [int]$existing.repair_success_runs_total
      $summary.completed_rounds_total = [int]$existing.completed_rounds_total
      $summary.repair_runs_total = [int]$existing.repair_runs_total
      $summary.average_completed_rounds = [double]$existing.average_completed_rounds
      $summary.quickcheck_runs_total = [int]$existing.quickcheck_runs_total
      $summary.quickcheck_wall_clock_seconds_total = [double]$existing.quickcheck_wall_clock_seconds_total
      $summary.quickcheck_average_wall_clock_seconds = [double]$existing.quickcheck_average_wall_clock_seconds
      $summary.quickcheck_tests_total = [int]$existing.quickcheck_tests_total
      $summary.quickcheck_passed_total = [int]$existing.quickcheck_passed_total
      $summary.quickcheck_failed_total = [int]$existing.quickcheck_failed_total
      $summary.operator_focus = [string]$existing.operator_focus
      $summary.operator_focus_reason = [string]$existing.operator_focus_reason
      Merge-CountMap -Destination $summary.issue_type_counts -SourceMap $existing.issue_type_counts
      Merge-CountMap -Destination $summary.issue_source_counts -SourceMap $existing.issue_source_counts
      Merge-CountMap -Destination $summary.decision_action_counts -SourceMap $existing.decision_action_counts
      Merge-CountMap -Destination $summary.quickcheck_family_counts -SourceMap $existing.quickcheck_family_counts
      Merge-CountMap -Destination $summary.quickcheck_test_counts -SourceMap $existing.quickcheck_test_counts
      Merge-CountMap -Destination $summary.final_status_counts -SourceMap $existing.final_status_counts
    }
    catch {
      # If summary is unreadable, start a fresh one rather than breaking callers.
    }
  }

  $source = [string]$payload.source
  $summary.generated_at = (Get-Date -Format 'o')
  $summary.last_source = $source

  if ($source -eq 'detector_round') {
    $summary.detector_runs_total = [int]$summary.detector_runs_total + 1
    if ($Metrics.PSObject.Properties.Name -contains 'detector_status') {
      $status = [string]$Metrics.detector_status
      if ($status -eq 'primary_failed_fallback_used') {
        $summary.detector_fallback_used_total = [int]$summary.detector_fallback_used_total + 1
      }
    }
    Merge-CountMap -Destination $summary.issue_type_counts -SourceMap $Metrics.issue_type_counts
    Merge-CountMap -Destination $summary.issue_source_counts -SourceMap $Metrics.issue_source_counts
    Merge-CountMap -Destination $summary.decision_action_counts -SourceMap $Metrics.decision_action_counts
  }

  if ($source -eq 'repair_loop_auto') {
    $summary.repair_runs_total = [int]$summary.repair_runs_total + 1
    $summary.repair_attempts_total = [int]$summary.repair_attempts_total + [int]$Metrics.repair_attempts_total
    $summary.repair_applied_total = [int]$summary.repair_applied_total + [int]$Metrics.repair_applied_total
    $summary.repair_blocked_total = [int]$summary.repair_blocked_total + [int]$Metrics.repair_blocked_total
    $summary.completed_rounds_total = [int]$summary.completed_rounds_total + [int]$Metrics.completed_rounds
    if ([string]$Metrics.final_status -eq 'success') {
      $summary.repair_success_runs_total = [int]$summary.repair_success_runs_total + 1
    }
    Add-CountValue -Map $summary.final_status_counts -Key ([string]$Metrics.final_status)
    Merge-CountMap -Destination $summary.issue_type_counts -SourceMap $Metrics.issue_type_counts
    Merge-CountMap -Destination $summary.issue_source_counts -SourceMap $Metrics.issue_source_counts
    Merge-CountMap -Destination $summary.decision_action_counts -SourceMap $Metrics.decision_action_counts
    if ([int]$summary.repair_runs_total -gt 0) {
      $summary.average_completed_rounds = [Math]::Round(([double]$summary.completed_rounds_total / [int]$summary.repair_runs_total), 2)
    }
  }

  if ($source -eq 'quickcheck') {
    $summary.quickcheck_runs_total = [int]$summary.quickcheck_runs_total + 1
    if ($Metrics.PSObject.Properties.Name -contains 'wall_clock_seconds') {
      $summary.quickcheck_wall_clock_seconds_total = [double]$summary.quickcheck_wall_clock_seconds_total + [double]$Metrics.wall_clock_seconds
    }
    if ($Metrics.PSObject.Properties.Name -contains 'tests_total') {
      $summary.quickcheck_tests_total = [int]$summary.quickcheck_tests_total + [int]$Metrics.tests_total
    }
    if ($Metrics.PSObject.Properties.Name -contains 'tests_passed') {
      $summary.quickcheck_passed_total = [int]$summary.quickcheck_passed_total + [int]$Metrics.tests_passed
    }
    if ($Metrics.PSObject.Properties.Name -contains 'tests_failed') {
      $summary.quickcheck_failed_total = [int]$summary.quickcheck_failed_total + [int]$Metrics.tests_failed
    }
    Merge-CountMap -Destination $summary.quickcheck_family_counts -SourceMap $Metrics.test_family_counts
    Merge-CountMap -Destination $summary.quickcheck_test_counts -SourceMap $Metrics.test_counts
    if ([int]$summary.quickcheck_runs_total -gt 0) {
      $summary.quickcheck_average_wall_clock_seconds = [Math]::Round(([double]$summary.quickcheck_wall_clock_seconds_total / [int]$summary.quickcheck_runs_total), 2)
    }
  }

  $detectorRuns = [int]$summary.detector_runs_total
  $detectorFallback = [int]$summary.detector_fallback_used_total
  $detectorFallbackRate = Get-Percent -Numerator $detectorFallback -Denominator $detectorRuns
  $repairRuns = [int]$summary.repair_runs_total
  $repairSuccessRuns = [int]$summary.repair_success_runs_total
  $repairSuccessRate = Get-Percent -Numerator $repairSuccessRuns -Denominator $repairRuns
  $quickcheckRuns = [int]$summary.quickcheck_runs_total
  $quickcheckPassed = [int]$summary.quickcheck_passed_total
  $quickcheckPassRate = Get-Percent -Numerator $quickcheckPassed -Denominator ([int]$summary.quickcheck_tests_total)
  $topIssueTypes = @(Get-TopCountEntries -Counts $summary.issue_type_counts -Limit 5)
  $topQuickcheckFamilies = @(Get-TopCountEntries -Counts $summary.quickcheck_family_counts -Limit 5)
  $operatorFocus = Get-OperatorFocus -Summary $summary
  $trendState = Get-TrendState -OperatorFocus ([string]$operatorFocus.focus)
  $operatorNextActions = Get-OperatorNextActions -OperatorFocus ([string]$operatorFocus.focus)
  $operatorTaskHint = Get-OperatorTaskHint -OperatorFocus ([string]$operatorFocus.focus) -NextStepCategory (Get-NextStepCategory -OperatorFocus ([string]$operatorFocus.focus) -TrendState ([string]$trendState.state))
  $operatorPriorityAction = Get-OperatorPriorityAction -OperatorNextActions $operatorNextActions
  $operatorPriorityLevel = Get-OperatorPriorityLevel -OperatorFocus ([string]$operatorFocus.focus) -TrendState ([string]$trendState.state)
  $trendDigest = Get-TrendDigest `
    -Summary $summary `
    -RepairRuns $repairRuns `
    -RepairSuccessRate $repairSuccessRate `
    -OperatorFocus ([string]$operatorFocus.focus) `
    -TopIssueFamilies (Format-CountEntries (Get-TopCountEntries -Counts $summary.issue_type_counts -Limit 3)) `
    -TopQuickcheckFamilies (Format-CountEntries (Get-TopCountEntries -Counts $summary.quickcheck_family_counts -Limit 3)) `
    -DetectorRuns $detectorRuns `
    -DetectorFallback $detectorFallback `
    -QuickcheckRuns $quickcheckRuns `
    -QuickcheckTests ([int]$summary.quickcheck_tests_total) `
    -QuickcheckAverage ([double]$summary.quickcheck_average_wall_clock_seconds)
  $trendBreakdown = [pscustomobject]@{
    detector = [pscustomobject]@{
      runs = $detectorRuns
      fallback_used = $detectorFallback
      fallback_rate = $detectorFallbackRate
    }
    repair = [pscustomobject]@{
      runs = $repairRuns
      success_runs = $repairSuccessRuns
      success_rate = $repairSuccessRate
      average_completed_rounds = [double]$summary.average_completed_rounds
    }
    quickcheck = [pscustomobject]@{
      runs = $quickcheckRuns
      tests_total = [int]$summary.quickcheck_tests_total
      tests_passed = [int]$summary.quickcheck_passed_total
      tests_failed = [int]$summary.quickcheck_failed_total
      pass_rate = $quickcheckPassRate
      average_wall_clock_seconds = [double]$summary.quickcheck_average_wall_clock_seconds
    }
    top_issue_family = Get-TopEntryName -Entries $topIssueTypes
    top_quickcheck_family = Get-TopEntryName -Entries $topQuickcheckFamilies
    operator_focus = [string]$operatorFocus.focus
    operator_focus_reason = [string]$operatorFocus.reason
    operator_next_actions = $operatorNextActions
  }
  $publicSummary = Get-PublicSummary -OperatorFocus ([string]$operatorFocus.focus)
  $nextStepCategory = Get-NextStepCategory -OperatorFocus ([string]$operatorFocus.focus) -TrendState ([string]$trendState.state)
  $summary.operator_focus = [string]$operatorFocus.focus
  $summary.operator_focus_reason = [string]$operatorFocus.reason
  $summary.operator_next_actions = $operatorNextActions
  $summary.operator_priority_action = $operatorPriorityAction
  $summary.operator_priority_level = $operatorPriorityLevel
  $summary.next_step_category = $nextStepCategory
  $summary.operator_task_hint = $operatorTaskHint
  $summary.public_summary = $publicSummary
  $summary.repair_success_rate = $repairSuccessRate
  $summary.trend_state = [string]$trendState.state
  $summary.trend_state_reason = [string]$trendState.reason
  $summary.trend_digest = $trendDigest
  $summary.trend_breakdown = $trendBreakdown
  $summary.top_issue_types = $topIssueTypes
  $summary.operator_snapshot = Get-OperatorSnapshot `
    -OperatorFocus ([string]$operatorFocus.focus) `
    -OperatorFocusReason ([string]$operatorFocus.reason) `
    -OperatorNextActions $operatorNextActions `
    -NextStepCategory $nextStepCategory `
    -OperatorPriorityAction $operatorPriorityAction `
    -OperatorPriorityLevel $operatorPriorityLevel `
    -OperatorTaskHint $operatorTaskHint `
    -PublicSummary $publicSummary `
    -TrendState ([string]$trendState.state) `
    -TrendStateReason ([string]$trendState.reason) `
    -TrendDigest $trendDigest `
    -TrendBreakdown $trendBreakdown

  Write-JsonAtomically -Path $summaryPath -Json (([pscustomobject]$summary) | ConvertTo-Json -Depth 20)

  return $OutputPath
}

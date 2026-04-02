. "$PSScriptRoot\Invoke-DetectorRound.ps1"
. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"
. "$PSScriptRoot\Write-DiagnosticsMetrics.ps1"

function Invoke-RepairLoopAuto {
  param(
    [Parameter(Mandatory = $true)][string]$PagePath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [int]$MaxRounds = 3,
    [string]$PreferredDetector = "automator",
    [double]$RepairConfidenceThreshold = 0.50,
    [bool]$EnforcePageRecognition = $true,
    [switch]$CollectConsoleLog,
    [switch]$DisableConsoleLogCollection
  )

  if ($MaxRounds -lt 1) {
    throw "MaxRounds must be >= 1"
  }

  $history = @()
  $finalStatus = "failed"
  $finalReason = "max_rounds_reached"
  $detectorStatusCounts = @{}
  $issueTypeCounts = @{}
  $issueSourceCounts = @{}
  $decisionActionCounts = @{}
  $repairStatusCounts = @{}
  $repairAttemptsTotal = 0
  $repairAppliedTotal = 0
  $repairBlockedTotal = 0

  function Add-MetricCount {
    param(
      [hashtable]$Map,
      [string]$Key
    )

    $label = if ([string]::IsNullOrWhiteSpace($Key)) { 'unknown' } else { $Key }
    if (-not $Map.ContainsKey($label)) {
      $Map[$label] = 0
    }
    $Map[$label] = [int]$Map[$label] + 1
  }

  $collectConsoleEnabled = $true
  if ($PSBoundParameters.ContainsKey("CollectConsoleLog")) {
    $collectConsoleEnabled = [bool]$CollectConsoleLog
  }
  if ($DisableConsoleLogCollection) {
    $collectConsoleEnabled = $false
  }

  for ($i = 1; $i -le $MaxRounds; $i++) {
    $round = Invoke-DetectorRound `
      -PagePath $PagePath `
      -ProjectPath $ProjectPath `
      -PreferredDetector $PreferredDetector `
      -RepairConfidenceThreshold $RepairConfidenceThreshold `
      -EnforcePageRecognition:$EnforcePageRecognition `
      -CollectConsoleLog:$collectConsoleEnabled

    Add-MetricCount -Map $detectorStatusCounts -Key ([string]$round.detector_result.detector_status)
    Add-MetricCount -Map $issueTypeCounts -Key ([string]$round.detector_result.issue.issue_type)
    Add-MetricCount -Map $issueSourceCounts -Key ([string]$round.detector_result.issue.source)
    Add-MetricCount -Map $decisionActionCounts -Key ([string]$round.decision.action)

    if ($round.decision.action -eq "done") {
      $history += [PSCustomObject]@{
        round = $i
        action = "done"
        issue_type = [string]$round.detector_result.issue.issue_type
        detector_status = [string]$round.detector_result.detector_status
        issue_source = [string]$round.detector_result.issue.source
      }
      $finalStatus = "success"
      $finalReason = "all_checks_passed"
      break
    }

    if ($round.decision.action -eq "halt_manual") {
      $history += [PSCustomObject]@{
        round = $i
        action = "halt_manual"
        issue_type = [string]$round.detector_result.issue.issue_type
        detector_status = [string]$round.detector_result.detector_status
        issue_source = [string]$round.detector_result.issue.source
      }
      $finalStatus = "blocked"
      $finalReason = "non_retryable_issue"
      break
    }

    $exec = Invoke-RepairActionExecutor -Issue $round.detector_result.issue -ProjectPath $ProjectPath
    $repairAttemptsTotal++
    Add-MetricCount -Map $repairStatusCounts -Key ([string]$exec.status)
    if ($exec.applied) {
      $repairAppliedTotal++
    }
    else {
      $repairBlockedTotal++
    }
    $history += [PSCustomObject]@{
      round = $i
      action = [string]$round.decision.action
      issue_type = [string]$round.detector_result.issue.issue_type
      detector_status = [string]$round.detector_result.detector_status
      issue_source = [string]$round.detector_result.issue.source
      repair_status = [string]$exec.status
      repair_reason = [string]$exec.reason
      repair_applied = [bool]$exec.applied
    }

    if (-not $exec.applied) {
      $finalStatus = "blocked"
      $finalReason = [string]$exec.reason
      break
    }

    if ($i -eq $MaxRounds) {
      $finalStatus = "failed"
      $finalReason = "max_rounds_reached"
      break
    }
  }

  $metrics = [pscustomobject]@{
    source = 'repair_loop_auto'
    page_path = $PagePath
    project_path = $ProjectPath
    max_rounds = $MaxRounds
    completed_rounds = @($history).Count
    final_status = $finalStatus
    final_reason = $finalReason
    detector_status_counts = $detectorStatusCounts
    issue_type_counts = $issueTypeCounts
    issue_source_counts = $issueSourceCounts
    decision_action_counts = $decisionActionCounts
    repair_status_counts = $repairStatusCounts
    repair_attempts_total = $repairAttemptsTotal
    repair_applied_total = $repairAppliedTotal
    repair_blocked_total = $repairBlockedTotal
    timestamp = (Get-Date -Format "o")
  }

  Invoke-WriteDiagnosticsMetrics -Metrics $metrics | Out-Null

  return [PSCustomObject]@{
    status = $finalStatus
    reason = $finalReason
    max_rounds = $MaxRounds
    completed_rounds = @($history).Count
    history = $history
    timestamp = (Get-Date -Format "o")
  }
}

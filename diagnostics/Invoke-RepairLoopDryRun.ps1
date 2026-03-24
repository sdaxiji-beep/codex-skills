. "$PSScriptRoot\Invoke-DetectorRound.ps1"
. "$PSScriptRoot\Invoke-RepairStub.ps1"
. "$PSScriptRoot\Invoke-RepairActionGuard.ps1"

function Invoke-RepairLoopDryRun {
  param(
    [Parameter(Mandatory = $true)][string]$PagePath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [int]$MaxRounds = 1,
    [double]$RepairConfidenceThreshold = 0.50,
    [bool]$StopOnDuplicateIssue = $true
  )

  if ($MaxRounds -lt 1) {
    throw "MaxRounds must be >= 1"
  }

  $history = @()
  $final = $null
  $seenIssueIds = @{}
  $stopReason = "max_rounds_reached"

  for ($i = 1; $i -le $MaxRounds; $i++) {
    $round = Invoke-DetectorRound `
      -PagePath $PagePath `
      -ProjectPath $ProjectPath `
      -RepairConfidenceThreshold $RepairConfidenceThreshold

    $repairPlan = Invoke-RepairStub -DetectorRoundResult $round
    $guard = Invoke-RepairActionGuard -RepairPlan $repairPlan
    $issueId = [string]$round.detector_result.issue.issue_id
    $confidence = if ($round.detector_result.issue.PSObject.Properties['detector_confidence']) {
      [double]$round.detector_result.issue.detector_confidence
    } else {
      1.0
    }

    $entry = [PSCustomObject]@{
      round = $i
      detector_status = [string]$round.detector_result.detector_status
      issue_id = $issueId
      issue_status = [string]$round.detector_result.issue.status
      issue_type = [string]$round.detector_result.issue.issue_type
      issue_confidence = $confidence
      decision_action = [string]$round.decision.action
      repair_action = [string]$repairPlan.action_taken
      repair_status = [string]$repairPlan.status
      guard_status = [string]$guard.guard_status
      guard_reason = [string]$guard.guard_reason
    }
    $history += $entry

    $final = [PSCustomObject]@{
      round_result = $round
      repair_plan = $repairPlan
      guard = $guard
      round_index = $i
    }

    if ($guard.guard_status -ne 'allowed') {
      $stopReason = "guard_blocked"
      break
    }

    if ($round.decision.action -eq 'done') {
      $stopReason = "done"
      break
    }

    if ($round.decision.action -eq 'halt_manual') {
      $stopReason = "manual_halt"
      break
    }

    if ($StopOnDuplicateIssue -and -not [string]::IsNullOrWhiteSpace($issueId)) {
      if ($seenIssueIds.ContainsKey($issueId)) {
        $stopReason = "duplicate_issue_stopped"
        break
      }
      $seenIssueIds[$issueId] = $true
    }

    if ($i -ge $MaxRounds) {
      $stopReason = "max_rounds_reached"
      break
    }
  }

  return [PSCustomObject]@{
    mode = 'dry_run'
    max_rounds = $MaxRounds
    completed_rounds = @($history).Count
    unique_issue_count = @($seenIssueIds.Keys).Count
    stop_reason = $stopReason
    history = $history
    final = $final
    timestamp = (Get-Date -Format "o")
  }
}

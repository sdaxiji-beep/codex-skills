. "$PSScriptRoot\Invoke-DetectorRound.ps1"
. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

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

    if ($round.decision.action -eq "done") {
      $history += [PSCustomObject]@{
        round = $i
        action = "done"
        issue_type = [string]$round.detector_result.issue.issue_type
        detector_status = [string]$round.detector_result.detector_status
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
      }
      $finalStatus = "blocked"
      $finalReason = "non_retryable_issue"
      break
    }

    $exec = Invoke-RepairActionExecutor -Issue $round.detector_result.issue -ProjectPath $ProjectPath
    $history += [PSCustomObject]@{
      round = $i
      action = [string]$round.decision.action
      issue_type = [string]$round.detector_result.issue.issue_type
      detector_status = [string]$round.detector_result.detector_status
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

  return [PSCustomObject]@{
    status = $finalStatus
    reason = $finalReason
    max_rounds = $MaxRounds
    completed_rounds = @($history).Count
    history = $history
    timestamp = (Get-Date -Format "o")
  }
}

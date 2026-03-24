. "$PSScriptRoot\Invoke-RepairLoopDryRun.ps1"

function Assert-Equal {
  param(
    [Parameter(Mandatory = $true)]$Actual,
    [Parameter(Mandatory = $true)]$Expected,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if ($Actual -ne $Expected) {
    throw "assert failed: $Message (actual=$Actual expected=$Expected)"
  }
}

Write-Host "[test] Start RepairLoopDryRun guard-blocked check..." -ForegroundColor Cyan

function global:Invoke-DetectorRound {
  param([string]$PagePath, [string]$ProjectPath, [double]$RepairConfidenceThreshold)
  return [PSCustomObject]@{
    detector_result = [PSCustomObject]@{
      detector_status = "primary_detected_issue"
      issue = [PSCustomObject]@{
        issue_id = "guard-block-case|pages/store/home/index|automator"
        status = "failed"
        issue_type = "missing_required_element"
        severity = "critical"
        source = "automator"
        retryable = $true
        detector_confidence = 0.99
      }
    }
    decision = [PSCustomObject]@{
      action = "repair"
      reason = "critical_retryable_with_sufficient_confidence"
      issue_id = "guard-block-case|pages/store/home/index|automator"
    }
    round_status = "needs_action"
    timestamp = (Get-Date -Format "o")
  }
}

function global:Invoke-RepairStub {
  param([Parameter(Mandatory = $true)]$DetectorRoundResult)
  return [PSCustomObject]@{
    execution_mode = "live_write"
    action_taken = "repair_planned"
    status = "planned"
    reason = "intentional guard-block test"
    issue_id = [string]$DetectorRoundResult.decision.issue_id
    plan = @("mock live write attempt")
    timestamp = (Get-Date -Format "o")
  }
}

$res = Invoke-RepairLoopDryRun -PagePath "pages/store/home/index" -ProjectPath "G:\mock" -MaxRounds 2

Assert-Equal -Actual $res.stop_reason -Expected "guard_blocked" -Message "stop reason should be guard_blocked"
Assert-Equal -Actual $res.completed_rounds -Expected 1 -Message "guard block should stop in first round"
Assert-Equal -Actual $res.final.guard.guard_status -Expected "blocked" -Message "final guard status should be blocked"
Assert-Equal -Actual $res.final.guard.guard_reason -Expected "execution_mode_not_allowed" -Message "guard reason should indicate execution mode mismatch"

Write-Host "[test] PASS: guard-blocked path is enforced" -ForegroundColor Green
exit 0

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

Write-Host "[test] Start RepairLoopDryRun guardrail checks..." -ForegroundColor Cyan

# Case 1: duplicate issue should stop on second round.
function global:Invoke-DetectorRound {
  param([string]$PagePath, [string]$ProjectPath, [double]$RepairConfidenceThreshold)
  return [PSCustomObject]@{
    detector_result = [PSCustomObject]@{
      detector_status = "primary_detected_issue"
      issue = [PSCustomObject]@{
        issue_id = "missing_required_element|pages/store/home/index|automator"
        status = "failed"
        issue_type = "missing_required_element"
        severity = "critical"
        source = "automator"
        retryable = $true
        detector_confidence = 0.95
      }
    }
    decision = [PSCustomObject]@{
      action = "repair"
      reason = "critical_retryable_with_sufficient_confidence"
      issue_id = "missing_required_element|pages/store/home/index|automator"
    }
    round_status = "needs_action"
    timestamp = (Get-Date -Format "o")
  }
}

$dup = Invoke-RepairLoopDryRun -PagePath "pages/store/home/index" -ProjectPath "G:\mock" -MaxRounds 3 -StopOnDuplicateIssue $true
Assert-Equal -Actual $dup.stop_reason -Expected "duplicate_issue_stopped" -Message "duplicate issue stop reason"
Assert-Equal -Actual $dup.completed_rounds -Expected 2 -Message "duplicate issue should stop on round 2"

# Case 2: max rounds reached when duplicate stop disabled and issue id changes.
$script:counter = 0
function global:Invoke-DetectorRound {
  param([string]$PagePath, [string]$ProjectPath, [double]$RepairConfidenceThreshold)
  $script:counter++
  $id = "issue-$script:counter|pages/store/home/index|automator"
  return [PSCustomObject]@{
    detector_result = [PSCustomObject]@{
      detector_status = "primary_detected_issue"
      issue = [PSCustomObject]@{
        issue_id = $id
        status = "failed"
        issue_type = "missing_required_element"
        severity = "critical"
        source = "automator"
        retryable = $true
        detector_confidence = 0.95
      }
    }
    decision = [PSCustomObject]@{
      action = "repair"
      reason = "critical_retryable_with_sufficient_confidence"
      issue_id = $id
    }
    round_status = "needs_action"
    timestamp = (Get-Date -Format "o")
  }
}

$max = Invoke-RepairLoopDryRun -PagePath "pages/store/home/index" -ProjectPath "G:\mock" -MaxRounds 2 -StopOnDuplicateIssue $false
Assert-Equal -Actual $max.stop_reason -Expected "max_rounds_reached" -Message "max rounds stop reason"
Assert-Equal -Actual $max.completed_rounds -Expected 2 -Message "max rounds should finish exactly MaxRounds"

Write-Host "[test] PASS: RepairLoopDryRun guardrails are enforced" -ForegroundColor Green
exit 0

function Invoke-RepairStub {
  param(
    [Parameter(Mandatory = $true)]$DetectorRoundResult
  )

  if ($null -eq $DetectorRoundResult) {
    throw "detector round result is null"
  }

  if ($null -eq $DetectorRoundResult.decision) {
    throw "detector round result missing decision"
  }

  $decision = $DetectorRoundResult.decision
  $issue = $DetectorRoundResult.detector_result.issue

  $action = [string]$decision.action
  switch ($action) {
    'done' {
      return [PSCustomObject]@{
        execution_mode = 'dry_run'
        action_taken = 'none'
        status = 'no_repair_needed'
        reason = [string]$decision.reason
        issue_id = [string]$decision.issue_id
        plan = @()
        timestamp = (Get-Date -Format "o")
      }
    }
    'repair' {
      return [PSCustomObject]@{
        execution_mode = 'dry_run'
        action_taken = 'repair_planned'
        status = 'planned'
        reason = [string]$decision.reason
        issue_id = [string]$decision.issue_id
        plan = @(
          "collect issue context",
          "generate repair spec",
          "apply repair via guarded write",
          "rerun detector round"
        )
        target = [string]$issue.target
        issue_type = [string]$issue.issue_type
        timestamp = (Get-Date -Format "o")
      }
    }
    'verify_then_repair' {
      return [PSCustomObject]@{
        execution_mode = 'dry_run'
        action_taken = 'verify_planned'
        status = 'planned'
        reason = [string]$decision.reason
        issue_id = [string]$decision.issue_id
        plan = @(
          "run secondary verification",
          "if confirmed then generate repair spec",
          "apply repair via guarded write",
          "rerun detector round"
        )
        timestamp = (Get-Date -Format "o")
      }
    }
    'halt_manual' {
      return [PSCustomObject]@{
        execution_mode = 'dry_run'
        action_taken = 'halt'
        status = 'manual_required'
        reason = [string]$decision.reason
        issue_id = [string]$decision.issue_id
        plan = @("stop loop and request manual intervention")
        timestamp = (Get-Date -Format "o")
      }
    }
    default {
      return [PSCustomObject]@{
        execution_mode = 'dry_run'
        action_taken = 'observe'
        status = 'deferred'
        reason = [string]$decision.reason
        issue_id = [string]$decision.issue_id
        plan = @("record issue and continue observation")
        timestamp = (Get-Date -Format "o")
      }
    }
  }
}

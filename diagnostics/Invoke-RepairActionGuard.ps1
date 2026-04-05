function Invoke-RepairActionGuard {
  param(
    [Parameter(Mandatory = $true)]$RepairPlan
  )

  if ($null -eq $RepairPlan) {
    throw "repair plan is null"
  }

  $allowedActions = @(
    "none",
    "repair_planned",
    "verify_planned",
    "halt",
    "observe"
  )

  $mode = [string]$RepairPlan.execution_mode
  $action = [string]$RepairPlan.action_taken

  if ($mode -ne "dry_run") {
    return [PSCustomObject]@{
      guard_status = "blocked"
      guard_reason = "execution_mode_not_allowed"
      allowed_actions = $allowedActions
      action_taken = $action
      timestamp = (Get-Date -Format "o")
    }
  }

  if ($action -notin $allowedActions) {
    return [PSCustomObject]@{
      guard_status = "blocked"
      guard_reason = "action_not_allowlisted"
      allowed_actions = $allowedActions
      action_taken = $action
      timestamp = (Get-Date -Format "o")
    }
  }

  return [PSCustomObject]@{
    guard_status = "allowed"
    guard_reason = "allowlisted_dry_run_action"
    allowed_actions = $allowedActions
    action_taken = $action
    timestamp = (Get-Date -Format "o")
  }
}

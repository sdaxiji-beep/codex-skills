. "$PSScriptRoot\Invoke-RepairActionGuard.ps1"

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

Write-Host "[test] Start RepairActionGuard checks..." -ForegroundColor Cyan

$allowed = Invoke-RepairActionGuard -RepairPlan ([PSCustomObject]@{
  execution_mode = "dry_run"
  action_taken = "repair_planned"
})
Assert-Equal -Actual $allowed.guard_status -Expected "allowed" -Message "allowlisted action should pass"

$blockedAction = Invoke-RepairActionGuard -RepairPlan ([PSCustomObject]@{
  execution_mode = "dry_run"
  action_taken = "shell_execute"
})
Assert-Equal -Actual $blockedAction.guard_status -Expected "blocked" -Message "unknown action should block"
Assert-Equal -Actual $blockedAction.guard_reason -Expected "action_not_allowlisted" -Message "blocked reason should match"

$blockedMode = Invoke-RepairActionGuard -RepairPlan ([PSCustomObject]@{
  execution_mode = "real_write"
  action_taken = "repair_planned"
})
Assert-Equal -Actual $blockedMode.guard_status -Expected "blocked" -Message "non dry_run mode should block"
Assert-Equal -Actual $blockedMode.guard_reason -Expected "execution_mode_not_allowed" -Message "mode blocked reason should match"

Write-Host "[test] PASS: repair action guard enforces allowlist" -ForegroundColor Green
exit 0

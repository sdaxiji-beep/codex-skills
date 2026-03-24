. "$PSScriptRoot\Invoke-RepairLoopDryRun.ps1"

function Assert-True {
  param(
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if (-not $Condition) {
    throw "assert failed: $Message"
  }
}

Write-Host "[test] Start RepairLoopDryRun JSON contract check..." -ForegroundColor Cyan

$projectPath = Join-Path 'G:\' ([string]([char]0x5C0F) + [char]0x7A0B + [char]0x5E8F + [char]0x6D4B + [char]0x8BD5)
$res = Invoke-RepairLoopDryRun -PagePath "pages/store/home/index" -ProjectPath $projectPath -MaxRounds 1

$json = $res | ConvertTo-Json -Depth 12
$parsed = $json | ConvertFrom-Json -ErrorAction Stop

$requiredTop = @("mode", "max_rounds", "completed_rounds", "unique_issue_count", "stop_reason", "history", "final", "timestamp")
$missingTop = $requiredTop | Where-Object { -not $parsed.PSObject.Properties[$_] }
Assert-True -Condition ($missingTop.Count -eq 0) -Message ("missing top fields: " + ($missingTop -join ", "))

Assert-True -Condition ($parsed.mode -eq "dry_run") -Message "mode should be dry_run"
Assert-True -Condition ($parsed.history.Count -ge 1) -Message "history should contain at least one row"

$requiredHistory = @("round", "detector_status", "issue_id", "issue_status", "issue_type", "issue_confidence", "decision_action", "repair_action", "repair_status", "guard_status", "guard_reason")
$missingHistory = $requiredHistory | Where-Object { -not $parsed.history[0].PSObject.Properties[$_] }
Assert-True -Condition ($missingHistory.Count -eq 0) -Message ("missing history fields: " + ($missingHistory -join ", "))

$requiredGuard = @("guard_status", "guard_reason")
$missingGuard = $requiredGuard | Where-Object { -not $parsed.final.guard.PSObject.Properties[$_] }
Assert-True -Condition ($missingGuard.Count -eq 0) -Message ("missing final.guard fields: " + ($missingGuard -join ", "))

Write-Host "[test] PASS: RepairLoopDryRun JSON contract is valid" -ForegroundColor Green
exit 0

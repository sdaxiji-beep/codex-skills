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

Write-Host "[test] Start RepairLoopDryRun history contract check..." -ForegroundColor Cyan

$projectPath = Join-Path 'G:\' ([string]([char]0x5C0F) + [char]0x7A0B + [char]0x5E8F + [char]0x6D4B + [char]0x8BD5)
$res = Invoke-RepairLoopDryRun -PagePath "pages/store/home/index" -ProjectPath $projectPath -MaxRounds 1

Assert-True -Condition ($res.history.Count -ge 1) -Message "history should contain at least one entry"
$h = $res.history[0]

$requiredFields = @(
  "round",
  "detector_status",
  "issue_id",
  "issue_status",
  "issue_type",
  "issue_confidence",
  "decision_action",
  "repair_action",
  "repair_status",
  "guard_status",
  "guard_reason"
)

$missing = $requiredFields | Where-Object { -not $h.PSObject.Properties[$_] }
Assert-True -Condition ($missing.Count -eq 0) -Message ("missing history fields: " + ($missing -join ", "))

$confidence = [double]$h.issue_confidence
Assert-True -Condition ($confidence -ge 0.0 -and $confidence -le 1.0) -Message "issue_confidence should be in [0,1]"

Write-Host "[test] PASS: repair loop history contract is valid" -ForegroundColor Green
exit 0

. "$PSScriptRoot\Get-SharedDiagnosticsDetectorResults.ps1"

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

$repoRoot = Split-Path $PSScriptRoot -Parent
$projectPath = Join-Path $repoRoot 'sandbox\fake-project'
$res = Get-SharedRepairLoopDryRunResult -PagePath "pages/store/home/index" -ProjectPath $projectPath -MaxRounds 1
$first = $res.history[0]

Assert-True -Condition ($res.history.Count -ge 1) -Message "history should contain at least one round"
Assert-True -Condition ($first.PSObject.Properties.Name -contains 'decision_action') -Message "history decision_action should exist"
Assert-True -Condition ($first.PSObject.Properties.Name -contains 'repair_status') -Message "history repair_status should exist"
Assert-True -Condition ($first.PSObject.Properties.Name -contains 'guard_status') -Message "history guard_status should exist"

Write-Host "[test] PASS: repair loop history contract valid" -ForegroundColor Green
exit 0

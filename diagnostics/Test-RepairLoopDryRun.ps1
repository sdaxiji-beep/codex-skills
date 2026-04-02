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

Write-Host "[test] Start RepairLoopDryRun minimal check..." -ForegroundColor Cyan

$repoRoot = Split-Path $PSScriptRoot -Parent
$projectPath = Join-Path $repoRoot 'sandbox\fake-project'
$res = Get-SharedRepairLoopDryRunResult -PagePath "pages/store/home/index" -ProjectPath $projectPath -MaxRounds 1

Write-Host "[test] mode=$($res.mode)"
Write-Host "[test] completed_rounds=$($res.completed_rounds)"
Write-Host "[test] stop_reason=$($res.stop_reason)"
Write-Host "[test] final_decision=$($res.final.round_result.decision.action)"
Write-Host "[test] final_repair_status=$($res.final.repair_plan.status)"

Assert-True -Condition ($res.mode -eq 'dry_run') -Message "mode should be dry_run"
Assert-True -Condition ($res.completed_rounds -ge 1) -Message "should run at least one round"
Assert-True -Condition (-not [string]::IsNullOrWhiteSpace([string]$res.stop_reason)) -Message "stop_reason should be set"
Assert-True -Condition ($null -ne $res.final.round_result) -Message "final round result should exist"
Assert-True -Condition ($null -ne $res.final.repair_plan) -Message "final repair plan should exist"

Write-Host "[test] PASS: repair loop dry-run contract valid" -ForegroundColor Green
exit 0

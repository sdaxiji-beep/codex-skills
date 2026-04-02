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

Write-Host "[test] Start RepairLoopDryRun JSON contract check..." -ForegroundColor Cyan

$repoRoot = Split-Path $PSScriptRoot -Parent
$projectPath = Join-Path $repoRoot 'sandbox\fake-project'
$res = Get-SharedRepairLoopDryRunResult -PagePath "pages/store/home/index" -ProjectPath $projectPath -MaxRounds 1
$json = $res | ConvertTo-Json -Depth 10
$parsed = $json | ConvertFrom-Json

Assert-True -Condition ($parsed.mode -eq $res.mode) -Message "mode should round-trip"
Assert-True -Condition ($parsed.stop_reason -eq $res.stop_reason) -Message "stop_reason should round-trip"
Assert-True -Condition ($parsed.final.round_result.decision.action -eq $res.final.round_result.decision.action) -Message "decision should round-trip"

Write-Host "[test] PASS: repair loop JSON contract valid" -ForegroundColor Green
exit 0

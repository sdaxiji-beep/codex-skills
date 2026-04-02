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

Write-Host "[test] Start DetectorRound minimal check..." -ForegroundColor Cyan

$repoRoot = Split-Path $PSScriptRoot -Parent
$projectPath = Join-Path $repoRoot 'sandbox\fake-project'
$round = Get-SharedDetectorRoundResult -PagePath "pages/store/home/index" -ProjectPath $projectPath

Write-Host "[test] round_status=$($round.round_status)"
Write-Host "[test] detector_status=$($round.detector_result.detector_status)"
Write-Host "[test] decision_action=$($round.decision.action)"
Write-Host "[test] issue_status=$($round.detector_result.issue.status)"
Write-Host "[test] issue_source=$($round.detector_result.issue.source)"
Write-Host "[test] issue_confidence=$($round.detector_result.issue.detector_confidence)"

Assert-True -Condition ($null -ne $round.detector_result) -Message "detector_result should exist"
Assert-True -Condition ($null -ne $round.decision) -Message "decision should exist"
Assert-True -Condition ($round.decision.PSObject.Properties.Name -contains 'action') -Message "decision.action should exist"

Write-Host "[test] PASS: detector round contract valid" -ForegroundColor Green
exit 0

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

Write-Host "[test] Start DetectorRound JSON contract check..." -ForegroundColor Cyan

$repoRoot = Split-Path $PSScriptRoot -Parent
$projectPath = Join-Path $repoRoot 'sandbox\fake-project'
$round = Get-SharedDetectorRoundResult -PagePath "pages/store/home/index" -ProjectPath $projectPath
$json = $round | ConvertTo-Json -Depth 8
$parsed = $json | ConvertFrom-Json

Assert-True -Condition ($parsed.round_status -eq $round.round_status) -Message "round_status should round-trip"
Assert-True -Condition ($parsed.detector_result.issue.issue_type -eq $round.detector_result.issue.issue_type) -Message "issue_type should round-trip"
Assert-True -Condition ($parsed.decision.action -eq $round.decision.action) -Message "decision.action should round-trip"

Write-Host "[test] PASS: detector round JSON contract valid" -ForegroundColor Green
exit 0

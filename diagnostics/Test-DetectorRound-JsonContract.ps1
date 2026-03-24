. "$PSScriptRoot\Invoke-DetectorRound.ps1"

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

$projectPath = Join-Path 'G:\' ([string]([char]0x5C0F) + [char]0x7A0B + [char]0x5E8F + [char]0x6D4B + [char]0x8BD5)
$round = Invoke-DetectorRound -PagePath "pages/store/home/index" -ProjectPath $projectPath

$json = $round | ConvertTo-Json -Depth 10
$parsed = $json | ConvertFrom-Json -ErrorAction Stop

$requiredTop = @("detector_result", "decision", "round_status", "timestamp")
$missingTop = $requiredTop | Where-Object { -not $parsed.PSObject.Properties[$_] }
Assert-True -Condition ($missingTop.Count -eq 0) -Message ("missing top fields: " + ($missingTop -join ", "))

$requiredIssue = @("status", "severity", "source", "retryable")
$missingIssue = $requiredIssue | Where-Object { -not $parsed.detector_result.issue.PSObject.Properties[$_] }
Assert-True -Condition ($missingIssue.Count -eq 0) -Message ("missing issue fields: " + ($missingIssue -join ", "))

$requiredDecision = @("action", "reason", "issue_id")
$missingDecision = $requiredDecision | Where-Object { -not $parsed.decision.PSObject.Properties[$_] }
Assert-True -Condition ($missingDecision.Count -eq 0) -Message ("missing decision fields: " + ($missingDecision -join ", "))

Write-Host "[test] PASS: DetectorRound JSON contract is valid" -ForegroundColor Green
exit 0

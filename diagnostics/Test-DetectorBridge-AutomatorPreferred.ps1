. "$PSScriptRoot\Invoke-DetectorBridge.ps1"

function Assert-True {
  param(
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if (-not $Condition) {
    throw "assert failed: $Message"
  }
}

Write-Host "[test] Start DetectorBridge preferred automator check..." -ForegroundColor Cyan

function global:Invoke-AutomatorCheck {
  param([string]$PagePath, [string]$ProjectPath, [int]$AutoPort = 9420)
  return [PSCustomObject]@{
    issue_id = "passed|$PagePath|automator"
    status = "passed"
    issue_type = $null
    target = $null
    expected = "page healthy"
    actual = "page healthy"
    severity = "info"
    source = "automator"
    page_path = $PagePath
    project_path = $ProjectPath
    repair_hint = ""
    retryable = $false
    timestamp = (Get-Date -Format "o")
    detector_confidence = 1.0
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$projectPath = Join-Path $repoRoot 'sandbox\fake-project'
$res = Invoke-DetectorBridge -PagePath "pages/store/home/index" -ProjectPath $projectPath -PreferredDetector "automator"

Write-Host "[test] detector_status=$($res.detector_status)"
Write-Host "[test] detectors_tried=$($res.detectors_tried -join ' -> ')"
Write-Host "[test] issue_source=$($res.issue.source)"

Assert-True -Condition ($res.detector_status -eq "primary_passed") -Message "automator preferred status should be primary_passed"
Assert-True -Condition ($res.detectors_tried.Count -eq 1) -Message "automator preferred should not trigger fallback"
Assert-True -Condition ($res.detectors_tried[0] -eq "automator") -Message "detectors_tried should contain automator only"
Assert-True -Condition ($res.issue.source -eq "automator") -Message "issue source should be automator"

Write-Host "[test] PASS: preferred automator path is valid" -ForegroundColor Green
exit 0

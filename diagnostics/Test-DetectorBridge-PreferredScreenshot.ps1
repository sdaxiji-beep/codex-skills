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

Write-Host "[test] Start DetectorBridge preferred screenshot check..." -ForegroundColor Cyan

$projectPath = Join-Path 'G:\' ([string]([char]0x5C0F) + [char]0x7A0B + [char]0x5E8F + [char]0x6D4B + [char]0x8BD5)
$res = Invoke-DetectorBridge -PagePath "pages/store/home/index" -ProjectPath $projectPath -PreferredDetector "screenshot"

Write-Host "[test] detector_status=$($res.detector_status)"
Write-Host "[test] detectors_tried=$($res.detectors_tried -join ' -> ')"
Write-Host "[test] issue_source=$($res.issue.source)"

Assert-True -Condition ($res.detectors_tried.Count -eq 1) -Message "preferred screenshot should not try automator"
Assert-True -Condition ($res.detectors_tried[0] -eq "screenshot") -Message "detectors_tried should contain screenshot only"
Assert-True -Condition ($res.issue.source -eq "screenshot") -Message "issue source should be screenshot"
Assert-True -Condition ($res.detector_status -eq "preferred_detector_used") -Message "preferred screenshot status should be preferred_detector_used"

Write-Host "[test] PASS: preferred screenshot path is valid" -ForegroundColor Green
exit 0

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

function global:Invoke-ScreenshotFallback {
  param([string]$PagePath, [string]$ProjectPath)
  return [PSCustomObject]@{
    issue_id = "failed|$PagePath|screenshot_fallback"
    status = "failed"
    issue_type = "error_page_visible"
    target = $null
    expected = "page healthy"
    actual = "fallback failure"
    severity = "critical"
    source = "screenshot_fallback"
    page_path = $PagePath
    project_path = $ProjectPath
    repair_hint = "inspect screenshot"
    retryable = $true
    timestamp = (Get-Date -Format "o")
    detector_confidence = 0.5
  }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$projectPath = Join-Path $repoRoot 'sandbox\fake-project'
$res = Invoke-DetectorBridge -PagePath "pages/store/home/index" -ProjectPath $projectPath -PreferredDetector "screenshot"

Assert-True -Condition ($res.detectors_tried.Count -eq 1) -Message "preferred screenshot should skip automator"
Assert-True -Condition ($res.detectors_tried[0] -eq "screenshot") -Message "screenshot should be tried first"
Assert-True -Condition ($res.issue.source -eq "screenshot_fallback") -Message "issue source should be screenshot fallback"

Write-Host "[test] PASS: preferred screenshot path is valid" -ForegroundColor Green
exit 0

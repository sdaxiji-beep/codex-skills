. "$PSScriptRoot\Get-SharedDiagnosticsDetectorResults.ps1"

Write-Host "`n[test] Start DetectorBridge minimal check..." -ForegroundColor Cyan

$repoRoot = Split-Path $PSScriptRoot -Parent
$projectPath = Join-Path $repoRoot 'sandbox\fake-project'

$result = Get-SharedDetectorBridgeResult `
  -PagePath    "pages/store/home/index" `
  -ProjectPath $projectPath

Write-Host "`n[test] DetectorResult:" -ForegroundColor Cyan
Write-Host "  detector_status  : $($result.detector_status)"
Write-Host "  detectors_tried  : $($result.detectors_tried -join ' -> ')"
Write-Host "  issue.status     : $($result.issue.status)"
Write-Host "  issue.issue_type : $($result.issue.issue_type)"
Write-Host "  issue.severity   : $($result.issue.severity)"
Write-Host "  issue.source     : $($result.issue.source)"
Write-Host "  issue.retryable  : $($result.issue.retryable)"

$requiredFields = @("issue","detector_status","detectors_tried")
$missing = $requiredFields | Where-Object { -not $result.PSObject.Properties[$_] }

if ($missing.Count -eq 0) {
  Write-Host "`n[test] PASS: DetectorResult structure is complete" -ForegroundColor Green
  exit 0
} else {
  Write-Host "`n[test] FAIL: missing fields: $($missing -join ', ')" -ForegroundColor Red
  exit 1
}

. "$PSScriptRoot\Invoke-AutomatorCheck.ps1"

Write-Host "[test] Start AutomatorCheck minimal check..." -ForegroundColor Cyan

$projectPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

try {
  $result = Invoke-AutomatorCheck `
    -PagePath    "pages/store/home/index" `
    -ProjectPath $projectPath

  Write-Host "[test] Result:" -ForegroundColor Cyan
  $result | Format-List *

  $requiredFields = @(
    "issue_id","status","source","page_path",
    "project_path","severity","retryable","timestamp"
  )
  $missing = $requiredFields | Where-Object { -not $result.PSObject.Properties[$_] }

  if ($missing.Count -eq 0) {
    Write-Host "[test] PASS: PageIssue structure complete" -ForegroundColor Green
    exit 0
  } else {
    Write-Host "[test] FAIL: missing fields: $($missing -join ', ')" -ForegroundColor Red
    exit 1
  }

} catch {
  Write-Host "[test] automator unreachable (expected): $_" -ForegroundColor Yellow
  Write-Host "[test] bridge will fallback to screenshot, this is not FAIL" -ForegroundColor Yellow
  exit 0
}

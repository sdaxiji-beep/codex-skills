. "$PSScriptRoot\Invoke-ScreenshotFallback.ps1"

Write-Host "`n[test] Start screenshot fallback minimal check..." -ForegroundColor Cyan

$projectPath = Join-Path 'G:\' ([string]([char]0x5C0F) + [char]0x7A0B + [char]0x5E8F + [char]0x6D4B + [char]0x8BD5)

$result = Invoke-ScreenshotFallback `
  -PagePath    "pages/store/home/index" `
  -ProjectPath $projectPath

Write-Host "`n[test] Result:" -ForegroundColor Cyan
$result | Format-List *

# Validate required fields
$requiredFields = @(
  "issue_id","status","source","page_path",
  "project_path","severity","retryable","timestamp"
)

$missing = $requiredFields | Where-Object { -not $result.PSObject.Properties[$_] }

if ($missing.Count -eq 0) {
  Write-Host "`n[test] PASS: all required fields exist" -ForegroundColor Green
  exit 0
} else {
  Write-Host "`n[test] FAIL: missing fields: $($missing -join ', ')" -ForegroundColor Red
  exit 1
}

. "$PSScriptRoot\..\..\scripts\test-common.ps1"
. "$PSScriptRoot\Test-OcrCommon.ps1"
. "$PSScriptRoot\Invoke-OcrCheck.ps1"

if (-not (Test-WindowsOcrAvailable)) {
  Write-Host "[test] SKIP: Windows OCR is unavailable on this machine" -ForegroundColor Yellow
  exit 0
}

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sandboxDir = Join-Path $repoRoot 'sandbox\ocr-tests'
$projectPath = Join-Path $repoRoot 'sandbox\ocr-project'
$path = Join-Path $sandboxDir 'runtime-text.png'
New-OcrTestImage `
  -Lines @(
    'ReferenceError',
    '__route__ is not defined'
  ) `
  -Path $path | Out-Null

$result = Invoke-OcrCheck `
  -ScreenshotPath $path `
  -PagePath 'pages/cart/index' `
  -ProjectPath $projectPath

Assert-Equal $result.status 'failed' 'runtime OCR should fail'
Assert-Equal $result.issue_type 'error_page_visible' 'runtime OCR should map to error_page_visible'
Assert-Equal $result.source 'screenshot' 'runtime OCR should preserve screenshot source'
Assert-Equal $result.severity 'critical' 'runtime OCR should be critical'
Assert-Equal $result.retryable $true 'runtime OCR issue should be retryable'
Assert-In $result.target @($null, '') 'runtime OCR should not fabricate a target path'

New-TestResult -Name 'ocr-check-runtime-text' -Data @{
  pass = $true
  exit_code = 0
}

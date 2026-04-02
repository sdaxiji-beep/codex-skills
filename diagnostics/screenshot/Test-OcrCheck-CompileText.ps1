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
$path = Join-Path $sandboxDir 'compile-text.png'
New-OcrTestImage `
  -Lines @(
    '[ WXML compile error ] ./pages/cart/index.wxml',
    'Bad value with message unexpected token'
  ) `
  -Path $path | Out-Null

$result = Invoke-OcrCheck `
  -ScreenshotPath $path `
  -PagePath 'pages/cart/index' `
  -ProjectPath $projectPath

Assert-Equal $result.status 'failed' 'compile OCR should fail'
Assert-Equal $result.issue_type 'generation_gate_rejected' 'compile OCR should map to generation_gate_rejected'
Assert-Equal $result.source 'screenshot' 'compile OCR should preserve screenshot source'
Assert-Equal $result.severity 'critical' 'compile OCR should be critical'
Assert-Equal $result.retryable $true 'compile OCR issue should be retryable'
Assert-Equal $result.target 'pages/cart/index.wxml' 'compile OCR should normalize the WXML target path'

New-TestResult -Name 'ocr-check-compile-text' -Data @{
  pass = $true
  exit_code = 0
}

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
$path = Join-Path $sandboxDir 'pass-text.png'
New-OcrTestImage `
  -Lines @(
    'Mini Mall',
    'Cart Page'
  ) `
  -Path $path | Out-Null

$result = Invoke-OcrCheck `
  -ScreenshotPath $path `
  -PagePath 'pages/cart/index' `
  -ProjectPath $projectPath

Assert-Equal $result.status 'passed' 'non-blocker OCR should pass'
Assert-Equal $result.issue_type $null 'non-blocker OCR should not emit an issue type'
Assert-Equal $result.source 'screenshot' 'non-blocker OCR should preserve screenshot source'

New-TestResult -Name 'ocr-check-pass-through' -Data @{
  pass = $true
  exit_code = 0
}

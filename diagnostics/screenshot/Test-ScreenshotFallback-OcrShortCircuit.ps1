. "$PSScriptRoot\..\..\scripts\test-common.ps1"
. "$PSScriptRoot\Test-OcrCommon.ps1"
. "$PSScriptRoot\Invoke-ScreenshotFallback.ps1"

if (-not (Test-WindowsOcrAvailable)) {
  Write-Host "[test] SKIP: Windows OCR is unavailable on this machine" -ForegroundColor Yellow
  exit 0
}

$script:VisualInvoked = $false
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$sandboxDir = Join-Path $repoRoot 'sandbox\ocr-tests'
$projectPath = Join-Path $repoRoot 'sandbox\ocr-project'
$capturePath = Join-Path $sandboxDir 'fallback-short-circuit.png'
New-OcrTestImage `
  -Lines @(
    '[ WXML compile error ] ./pages/cart/index.wxml',
    'Bad value with message unexpected token'
  ) `
  -Path $capturePath | Out-Null

function Invoke-ScreenshotCapture {
  param([string]$OutputDir, [string]$FilePrefix)
  return $capturePath
}

function Invoke-VisualCheck {
  param([string]$ScreenshotPath, [string]$PagePath, [string]$ProjectPath)
  $script:VisualInvoked = $true
  return [PSCustomObject]@{
    issue_id     = "passed|$PagePath|screenshot"
    status       = "passed"
    issue_type   = $null
    target       = $null
    expected     = "page visually acceptable"
    actual       = "no critical visual anomaly detected"
    severity     = "info"
    source       = "screenshot"
    page_path    = $PagePath
    project_path = $ProjectPath
    repair_hint  = ""
    retryable    = $false
    timestamp    = (Get-Date -Format "o")
  }
}

$result = Invoke-ScreenshotFallback `
  -PagePath 'pages/cart/index' `
  -ProjectPath $projectPath

Assert-Equal $result.status 'failed' 'fallback should return the OCR blocker'
Assert-Equal $result.issue_type 'generation_gate_rejected' 'fallback should short-circuit to OCR compile issue'
Assert-Equal $script:VisualInvoked $true 'fallback should keep the current visual-first contract before OCR'
Assert-Equal $result.ocr_status 'matched_blocker_text' 'fallback should tag OCR match status'

New-TestResult -Name 'screenshot-fallback-ocr-short-circuit' -Data @{
  pass = $true
  exit_code = 0
}

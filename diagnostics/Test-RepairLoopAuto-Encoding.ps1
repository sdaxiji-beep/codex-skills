. "$PSScriptRoot\Invoke-RepairLoopAuto.ps1"

function Assert-Equal {
  param($Actual, $Expected, [string]$Message)
  if ($Actual -ne $Expected) {
    throw "assert failed: $Message (actual=$Actual expected=$Expected)"
  }
}

Write-Host "[test] Start RepairLoopAuto encoding fix check..." -ForegroundColor Cyan

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-auto-encoding-" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

@'
{
  "pages": ["pages/home/index"],
  "window": {
    "navigationBarTitleText": "%E5%B0%8F%E5%BA%97"
  },
  "tabBar": {
    "list": [
      { "pagePath": "pages/home/index", "text": "Home?" },
      { "pagePath": "pages/cart/index", "text": "Cart?" }
    ]
  }
}
'@ | Set-Content -Path (Join-Path $tmp "app.json") -Encoding UTF8

function global:Invoke-DetectorBridge {
  param([string]$PagePath, [string]$ProjectPath, [string]$PreferredDetector = "automator")
  return [PSCustomObject]@{
    issue = [PSCustomObject]@{
      issue_id = "passed|$PagePath|mock"
      status = "passed"
      issue_type = $null
      target = $null
      expected = "page healthy"
      actual = "page healthy"
      severity = "info"
      source = "mock"
      page_path = $PagePath
      project_path = $ProjectPath
      repair_hint = ""
      retryable = $false
      timestamp = (Get-Date -Format "o")
      detector_confidence = 1.0
    }
    detector_status = "mock_primary_passed"
    detectors_tried = @("mock")
  }
}

$res = Invoke-RepairLoopAuto -PagePath "pages/home/index" -ProjectPath $tmp -MaxRounds 3 -PreferredDetector "automator"
Assert-Equal $res.status "success" "auto repair loop should converge to success"

$app = Get-Content (Join-Path $tmp "app.json") -Raw -Encoding UTF8 | ConvertFrom-Json
Assert-Equal $app.window.navigationBarTitleText "Mini Mall" "title should be normalized"
Assert-Equal $app.tabBar.list[0].text "Home" "tab text should be normalized"

Write-Host "[test] PASS: auto repair loop fixed encoding issue" -ForegroundColor Green
exit 0


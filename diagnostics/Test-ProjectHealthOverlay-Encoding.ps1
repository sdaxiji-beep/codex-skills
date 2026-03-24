. "$PSScriptRoot\Invoke-ProjectHealthOverlay.ps1"

function Assert-Equal {
  param($Actual, $Expected, [string]$Message)
  if ($Actual -ne $Expected) {
    throw "assert failed: $Message (actual=$Actual expected=$Expected)"
  }
}

Write-Host "[test] Start ProjectHealthOverlay encoding check..." -ForegroundColor Cyan

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("overlay-encoding-" + [System.Guid]::NewGuid().ToString("N"))
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
      { "pagePath": "pages/cart/index", "text": "Cart" }
    ]
  }
}
'@ | Set-Content -Path (Join-Path $tmp "app.json") -Encoding UTF8

$issue = Invoke-ProjectHealthOverlay -PagePath "pages/home/index" -ProjectPath $tmp
Assert-Equal $issue.status "failed" "overlay should detect garbled text"
Assert-Equal $issue.issue_type "text_encoding_garbled" "issue type should be text_encoding_garbled"

Write-Host "[test] PASS: overlay detects encoding issue" -ForegroundColor Green
exit 0

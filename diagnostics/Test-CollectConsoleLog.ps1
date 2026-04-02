. "$PSScriptRoot\Invoke-CollectConsoleLog.ps1"

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "assert failed: $Message" }
}

Write-Host "[test] Start CollectConsoleLog check..." -ForegroundColor Cyan

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("collect-console-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

$src = Join-Path $tmp "src.log"
$out = Join-Path $tmp "latest.log"
"[ WXML compile error ] ./pages/cart/index.wxml" | Set-Content -Path $src -Encoding UTF8

try {
  $r = Invoke-CollectConsoleLog -ExtraSources @($src) -OutputPath $out -TailLines 50
  Assert-True (Test-Path $out) "output log should exist"
  $body = Get-Content -Path $out -Raw -Encoding UTF8
  Assert-True ($body -match 'pages/cart/index.wxml') "output should include source content"
  Assert-True ($r.source_count -ge 1) "source_count should be >= 1"
  Write-Host "[test] PASS: CollectConsoleLog writes latest.log" -ForegroundColor Green
  exit 0
}
finally {
  if (Test-Path $tmp) {
    Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}


. "$PSScriptRoot\Invoke-CompileHealthOverlay.ps1"

function Assert-True {
  param(
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if (-not $Condition) {
    throw "assert failed: $Message"
  }
}

Write-Host "[test] Start CompileHealthOverlay malformed WXML check..." -ForegroundColor Cyan

$sandboxRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("compile-overlay-test-" + [guid]::NewGuid().ToString("N"))
$pageRoot = Join-Path $sandboxRoot "pages\store\cart"
New-Item -ItemType Directory -Path $pageRoot -Force | Out-Null

try {
  @'
<view class="row">
  <text>{{item.price * item.qty`}}</text>
</view>
'@ | Set-Content -Path (Join-Path $pageRoot "index.wxml") -Encoding UTF8

  @"
Page({
  data: { item: { price: 2, qty: 3 } }
})
"@ | Set-Content -Path (Join-Path $pageRoot "index.js") -Encoding UTF8

  '{ "usingComponents": {} }' | Set-Content -Path (Join-Path $pageRoot "index.json") -Encoding UTF8
  '.row { padding: 12rpx; }' | Set-Content -Path (Join-Path $pageRoot "index.wxss") -Encoding UTF8

  $result = Invoke-CompileHealthOverlay `
    -PagePath "pages/store/cart/index" `
    -ProjectPath $sandboxRoot

  Write-Host "[test] issue_status=$($result.status)"
  Write-Host "[test] issue_type=$($result.issue_type)"
  Write-Host "[test] issue_source=$($result.source)"
  Write-Host "[test] issue_target=$($result.target)"

  Assert-True -Condition ($result.status -eq "failed") -Message "malformed WXML should be failed"
  Assert-True -Condition ($result.issue_type -eq "generation_gate_rejected") -Message "expected generation_gate_rejected"

  Write-Host "[test] PASS: malformed WXML detected by compile overlay" -ForegroundColor Green
  exit 0
}
finally {
  if (Test-Path $sandboxRoot) {
    Remove-Item -Path $sandboxRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

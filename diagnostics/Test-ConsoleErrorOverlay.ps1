. "$PSScriptRoot\Invoke-ConsoleErrorOverlay.ps1"

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "assert failed: $Message" }
}

Write-Host "[test] Start ConsoleErrorOverlay compile error check..." -ForegroundColor Cyan

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("console-overlay-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$repoRoot = Split-Path $PSScriptRoot -Parent

$logPath = Join-Path $tmp "latest.log"
@'
[ WXML compile error ] ./pages/cart/index.wxml
Bad value with message: unexpected token `.`.
at files://pages/cart/index.wxml#21
'@ | Set-Content -Path $logPath -Encoding UTF8

try {
  $issue = Invoke-ConsoleErrorOverlay `
    -PagePath "pages/cart/index" `
    -ProjectPath $repoRoot `
    -ConsoleLogPath $logPath

  Write-Host "[test] issue_status=$($issue.status)"
  Write-Host "[test] issue_type=$($issue.issue_type)"
  Write-Host "[test] issue_source=$($issue.source)"
  Write-Host "[test] issue_target=$($issue.target)"

  Assert-True ($issue.status -eq "failed") "console compile error should fail"
  Assert-True ($issue.issue_type -eq "generation_gate_rejected") "issue_type should be generation_gate_rejected"
  Assert-True ($issue.target -eq "pages/cart/index.wxml") "target should point to cart wxml"

  Write-Host "[test] PASS: ConsoleErrorOverlay catches compile errors" -ForegroundColor Green
  exit 0
}
finally {
  if (Test-Path $tmp) {
    Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

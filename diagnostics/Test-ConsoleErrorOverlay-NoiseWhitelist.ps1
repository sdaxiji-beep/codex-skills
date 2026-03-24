. "$PSScriptRoot\Invoke-ConsoleErrorOverlay.ps1"

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw "assert failed: $Message" }
}

Write-Host "[test] Start ConsoleErrorOverlay noise whitelist check..." -ForegroundColor Cyan

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("console-noise-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
$logPath = Join-Path $tmp "latest.log"

@'
游客模式
请注意游客模式下，调用 wx.operateWXData 是受限的
Error: SystemError (appServiceSDKScriptError)
{"errMsg":"webapi_getwxaasyncsecinfo:fail "}
[20204:20860:0324/165159.686:ERROR:CONSOLE(1)] "console.assert", source: devtools://devtools/bundled/ui/ActionRegistry.js (1)
'@ | Set-Content -Path $logPath -Encoding UTF8

try {
  $issue = Invoke-ConsoleErrorOverlay `
    -PagePath "pages/cart/index" `
    -ProjectPath "G:\codex专属" `
    -ConsoleLogPath $logPath

  Assert-True ($issue.status -eq "passed") "noise-only logs should not block"
  Assert-True ($issue.severity -eq "info") "noise-only logs should be info level"
  Write-Host "[test] PASS: noise whitelist works" -ForegroundColor Green
  exit 0
}
finally {
  if (Test-Path $tmp) {
    Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

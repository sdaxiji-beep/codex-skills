param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-auto-fix.ps1"

$stubSuite = Join-Path $env:TEMP 'codex-autofix-stub.ps1'
Set-Content -Path $stubSuite -Encoding UTF8 -Value @'
Write-Output "success=true"
'@

$r = Invoke-AutoFixLoop `
    -MaxRounds 1 `
    -RequireConfirm $false `
    -TestSuitePath $stubSuite

Assert-True ($r.status -in @('success', 'needs_fix', 'max_rounds_reached')) 'expected a clear status'
Assert-True ($r.ContainsKey('rounds') -or $r.ContainsKey('round')) 'expected round info'

New-TestResult -Name 'auto-fix' -Data @{
    pass      = $true
    exit_code = 0
    status    = $r.status
}

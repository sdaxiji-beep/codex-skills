param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-status.ps1"
. "$PSScriptRoot\test-common.ps1"
$threw = $false
try {
    Invoke-WechatStatus -StaleMinutes 0 | Out-Null
}
catch {
    $threw = $true
}
Assert-True $threw 'Expected stale=0 to be rejected by ValidateRange.'
New-TestResult -Name 'status-parameter-range' -Data @{ pass = $true; exit_code = 0; range_enforced = $true }

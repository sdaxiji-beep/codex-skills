param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-status.ps1"
. "$PSScriptRoot\test-common.ps1"
$result = Invoke-WechatStatus -StaleMinutes 5
Assert-Equal $result.process_exit_code 0 'Fresh status should exit 0.'
Assert-True $result.has_failure_summary_v2 'Status should expose failure summary contract.'
New-TestResult -Name 'status-freshness' -Data @{
    pass                   = $true
    exit_code              = 0
    process_exit_code      = $result.process_exit_code
    status                 = $result.status
    has_failure_summary_v2 = $result.has_failure_summary_v2
}

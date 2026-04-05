param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-status.ps1"
. "$PSScriptRoot\test-common.ps1"
$result = Invoke-WechatStatus -SimulateWriteFailure
Assert-Equal $result.process_exit_code 2 'Status write failure should exit 2.'
Assert-Equal $result.status 'warn' 'Status write failure should be warn.'
New-TestResult -Name 'status-report-write-failure' -Data @{
    pass              = $true
    exit_code         = 0
    process_exit_code = $result.process_exit_code
    status            = $result.status
}

param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-doctor.ps1"
. "$PSScriptRoot\test-common.ps1"
$result = Invoke-WechatDoctor -SimulateWriteFailure
Assert-Equal $result.status 'warn' 'Doctor failure result should be warn.'
New-TestResult -Name 'doctor-failure-result-contract-warn' -Data @{ pass = $true; exit_code = 0; status = $result.status }

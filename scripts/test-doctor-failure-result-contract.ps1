param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-doctor.ps1"
. "$PSScriptRoot\test-common.ps1"
$result = Invoke-WechatDoctor -SimulateWriteFailure
$hasFlag = $false
if ($result -is [hashtable]) {
    $hasFlag = $result.ContainsKey('has_failure_summary_v2')
}
else {
    $hasFlag = $result.PSObject.Properties.Name -contains 'has_failure_summary_v2'
}
Assert-True $hasFlag 'Doctor contract must expose has_failure_summary_v2.'
Assert-True $result.has_failure_summary_v2 'Doctor failure contract flag must be true.'
New-TestResult -Name 'doctor-failure-result-contract' -Data @{ pass = $true; exit_code = 0; has_failure_summary_v2 = $true }

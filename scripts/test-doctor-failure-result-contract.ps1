param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-doctor.ps1"
. "$PSScriptRoot\test-common.ps1"

if ($null -eq $Context) {
    $Context = @{}
}

$result = $null
if ($Context.ContainsKey('DoctorSimulatedFailureResult')) {
    $result = $Context.DoctorSimulatedFailureResult
}
else {
    $result = Invoke-WechatDoctor -SimulateWriteFailure
    $Context.DoctorSimulatedFailureResult = $result
}

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

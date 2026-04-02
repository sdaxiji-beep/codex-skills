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

Assert-Equal $result.status 'warn' 'Doctor failure result should be warn.'
New-TestResult -Name 'doctor-failure-result-contract-warn' -Data @{ pass = $true; exit_code = 0; status = $result.status }

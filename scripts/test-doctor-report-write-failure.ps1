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

Assert-Equal $result.process_exit_code 2 'Doctor write failure should return exit code 2.'
Assert-Equal $result.status 'warn' 'Doctor write failure should be warn.'
New-TestResult -Name 'doctor-report-write-failure' -Data @{ pass = $true; exit_code = 0; status = $result.status }

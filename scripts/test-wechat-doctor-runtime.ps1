param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-doctor.ps1"

if ($null -eq $Context) {
  $Context = @{}
}

$result = $null
if ($Context.ContainsKey('DoctorSharedResult')) {
  $result = $Context.DoctorSharedResult
}
elseif ($Context.ContainsKey('DoctorRuntimeResult')) {
  $result = $Context.DoctorRuntimeResult
}
elseif ($Context.ContainsKey('DoctorReportPathResult')) {
  $result = $Context.DoctorReportPathResult
}
else {
  $result = Invoke-WechatDoctor
}

$Context.DoctorSharedResult = $result
$Context.DoctorRuntimeResult = $result
$Context.DoctorReportPathResult = $result
$Context.DetectedDevtoolsPort = $result.port

Assert-In $result.status @('pass', 'warn') "doctor status should be pass or warn"
Assert-True ($result.port -gt 0) "doctor should return detected port"
Assert-True ($result.summary.total_checks -ge 4) "doctor should include at least 4 checks"
Assert-True ($result.summary.passed_checks -ge 1) "doctor should have at least one passed check"
Assert-True (Test-Path $result.report_path) "doctor report should be written"

New-TestResult -Name "wechat-doctor-runtime" -Data @{
  pass       = $true
  exit_code  = 0
  status     = $result.status
  port       = $result.port
  checks     = $result.summary.total_checks
}

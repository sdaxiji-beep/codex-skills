param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat-doctor.ps1"

$result = Invoke-WechatDoctor

Assert-In $result.status @('pass', 'warn') "doctor status should be pass or warn"
Assert-True ($result.port -gt 0) "doctor should return detected port"
Assert-True ($result.summary.total_checks -ge 5) "doctor should include at least 5 checks"
Assert-True ($result.summary.passed_checks -ge 1) "doctor should have at least one passed check"
Assert-True (Test-Path $result.report_path) "doctor report should be written"
Assert-True ($null -ne $result.release_setup) "doctor should include release setup readiness"

New-TestResult -Name "wechat-doctor-runtime" -Data @{
  pass       = $true
  exit_code  = 0
  status     = $result.status
  port       = $result.port
  checks     = $result.summary.total_checks
}

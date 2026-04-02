param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-doctor.ps1"
. "$PSScriptRoot\test-common.ps1"

if ($null -eq $Context) {
    $Context = @{}
}

$result = $null
if ($Context.ContainsKey('DoctorSharedResult')) {
    $result = $Context.DoctorSharedResult
}
elseif ($Context.ContainsKey('DoctorReportPathResult')) {
    $result = $Context.DoctorReportPathResult
}
elseif ($Context.ContainsKey('DoctorRuntimeResult')) {
    $result = $Context.DoctorRuntimeResult
}
else {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('codex-doctor-' + [guid]::NewGuid())
    $result = Invoke-WechatDoctor -ArtifactsRoot $tmp
}

$Context.DoctorSharedResult = $result
$Context.DoctorReportPathResult = $result
$Context.DoctorRuntimeResult = $result
$Context.DetectedDevtoolsPort = $result.port

Assert-True (Test-Path $result.report_path) 'Doctor report path must exist.'
New-TestResult -Name 'doctor-report-path' -Data @{ pass = $true; exit_code = 0; report_path = $result.report_path }

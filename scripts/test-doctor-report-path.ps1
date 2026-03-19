param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-doctor.ps1"
. "$PSScriptRoot\test-common.ps1"
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('codex-doctor-' + [guid]::NewGuid())
$result = Invoke-WechatDoctor -ArtifactsRoot $tmp
Assert-True (Test-Path $result.report_path) 'Doctor report path must exist.'
New-TestResult -Name 'doctor-report-path' -Data @{ pass = $true; exit_code = 0; report_path = $result.report_path }

param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-status.ps1"
. "$PSScriptRoot\wechat-report.ps1"
. "$PSScriptRoot\test-common.ps1"
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('codex-report-refresh-' + [guid]::NewGuid())
$status = Invoke-WechatStatus -ArtifactsRoot $tmp
$report = Invoke-WechatReport -ArtifactsRoot $tmp
Assert-True (Test-Path $status.report_path) 'Status summary must exist before refresh report check.'
New-TestResult -Name 'report-refresh-status' -Data @{
    pass              = $true
    exit_code         = 0
    process_exit_code = 0
    status_source     = $status.report_path
}

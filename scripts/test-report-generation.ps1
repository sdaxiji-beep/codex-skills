param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-report.ps1"
. "$PSScriptRoot\test-common.ps1"
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('codex-report-' + [guid]::NewGuid())
$result = Invoke-WechatReport -ArtifactsRoot $tmp
Assert-True (Test-Path $result.json_path) 'Report json must exist.'
Assert-True (Test-Path $result.md_path) 'Report markdown must exist.'
New-TestResult -Name 'report-generation' -Data @{
    pass                   = $true
    exit_code              = 0
    json_path              = $result.json_path
    md_path                = $result.md_path
    has_failure_summary_v2 = $result.has_failure_summary_v2
    has_scenarios          = $result.has_scenarios
    has_page_recognition   = $result.has_page_recognition
}

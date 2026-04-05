param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-report.ps1"
. "$PSScriptRoot\test-common.ps1"
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('codex-report-scenarios-' + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$summaryPath = Join-Path $tmp 'summary.json'
@{
    results = @(
        @{ name = 'p2-scenario-minimal-v1'; pass = $true },
        @{ name = 'p2-scenario-failure-v1'; pass = $true }
    )
} | ConvertTo-Json -Depth 5 | Set-Content -Path $summaryPath -Encoding UTF8
$report = Invoke-WechatReport -ArtifactsRoot $tmp -SummaryPath $summaryPath
Assert-Equal $report.scenarios_source 'test_wechat_skill_summary' 'Scenario fallback source mismatch.'
Assert-Equal $report.scenarios_count 2 'Scenario fallback count mismatch.'
New-TestResult -Name 'report-scenarios-fallback' -Data @{
    pass             = $true
    exit_code        = 0
    scenarios_source = $report.scenarios_source
    scenarios_count  = $report.scenarios_count
}

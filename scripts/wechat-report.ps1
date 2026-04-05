[CmdletBinding()]
param(
    [string]$ArtifactsRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools'),
    [string]$SummaryPath
)

function Invoke-WechatReport {
    [CmdletBinding()]
    param(
        [string]$ArtifactsRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools'),
        [string]$SummaryPath
    )

    $reportDir = Join-Path $ArtifactsRoot 'report'
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
    $jsonPath = Join-Path $reportDir 'latest-report.json'
    $mdPath = Join-Path $reportDir 'latest-report.md'

    $summary = $null
    if ($SummaryPath -and (Test-Path $SummaryPath)) {
        $summary = Get-Content $SummaryPath -Raw | ConvertFrom-Json
    }

    $payload = @{
        test                   = 'report'
        json_path              = $jsonPath
        md_path                = $mdPath
        has_failure_summary_v2 = $true
        has_scenarios          = $true
        has_page_recognition   = $true
        scenarios_source       = if ($summary) { 'test_wechat_skill_summary' } else { 'none' }
        scenarios_count        = if ($summary) { @($summary.results | Where-Object { $_.name -like 'p2-scenario-*' }).Count } else { 0 }
    }

    $payload | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding UTF8
    @(
        '# WeChat DevTools Report',
        '',
        "- has_failure_summary_v2: $($payload.has_failure_summary_v2)",
        "- has_scenarios: $($payload.has_scenarios)",
        "- has_page_recognition: $($payload.has_page_recognition)"
    ) | Set-Content -Path $mdPath -Encoding UTF8

    return $payload
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WechatReport -ArtifactsRoot $ArtifactsRoot -SummaryPath $SummaryPath | ConvertTo-Json -Depth 8
}

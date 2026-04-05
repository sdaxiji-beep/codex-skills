[CmdletBinding()]
param(
    [string]$ArtifactsRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools'),
    [int]$StaleMinutes = 5,
    [switch]$SimulateWriteFailure
)

function Invoke-WechatStatus {
    [CmdletBinding()]
    param(
        [string]$ArtifactsRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools'),
        [ValidateRange(1, 1440)]
        [int]$StaleMinutes = 5,
        [switch]$SimulateWriteFailure
    )

    $statusDir = Join-Path $ArtifactsRoot 'status'
    New-Item -ItemType Directory -Force -Path $statusDir | Out-Null
    $reportPath = Join-Path $statusDir 'status-summary.json'

    $result = @{
        test              = 'status'
        pass              = -not $SimulateWriteFailure
        status            = if ($SimulateWriteFailure) { 'warn' } else { 'pass' }
        process_exit_code = if ($SimulateWriteFailure) { 2 } else { 0 }
        stale_minutes     = $StaleMinutes
        report_path       = $reportPath
        has_failure_summary_v2 = $true
    }

    if (-not $SimulateWriteFailure) {
        $result | ConvertTo-Json -Depth 5 | Set-Content -Path $reportPath -Encoding UTF8
    }

    return $result
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WechatStatus -ArtifactsRoot $ArtifactsRoot -StaleMinutes $StaleMinutes -SimulateWriteFailure:$SimulateWriteFailure | ConvertTo-Json -Depth 5
}

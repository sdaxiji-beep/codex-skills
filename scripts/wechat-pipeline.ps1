[CmdletBinding()]
param(
    [string]$SummaryPath
)

. "$PSScriptRoot\wechat-gate.ps1"

function Invoke-WechatPipeline {
    [CmdletBinding()]
    param([string]$SummaryPath)

    $gate = Invoke-WechatGate -SummaryPath $SummaryPath
    return @{
        interface_version = 'v1'
        pipeline_status   = if ($gate.gate_pass) { 'pass' } else { 'warn' }
        gate              = $gate
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WechatPipeline -SummaryPath $SummaryPath | ConvertTo-Json -Depth 6
}

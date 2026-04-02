[CmdletBinding()]
param(
    [string]$SummaryPath
)

function Invoke-WechatGate {
    [CmdletBinding()]
    param([string]$SummaryPath)

    $summary = $null
    if ($SummaryPath -and (Test-Path $SummaryPath)) {
        $summary = Get-Content $SummaryPath -Raw | ConvertFrom-Json
    }

    $pass = $false
    if ($summary) {
        $pass = [bool]$summary.success
    }

    return @{
        interface_version = 'v1'
        gate_declared     = $true
        pipeline_declared = $true
        gate_pass         = $pass
        process_exit_code = if ($pass) { 0 } else { 2 }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WechatGate -SummaryPath $SummaryPath | ConvertTo-Json -Depth 4
}

[CmdletBinding()]
param()

function Get-WechatWindowState {
    [CmdletBinding()]
    param()

    return @{
        window_found      = $true
        simulator_visible = $true
        interaction_ready = $true
        source            = 'window_control_stub_v1'
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Get-WechatWindowState | ConvertTo-Json -Depth 4
}

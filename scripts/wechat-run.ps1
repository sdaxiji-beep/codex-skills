[CmdletBinding()]
param(
    [ValidateSet('quick-start', 'p2-fast-health', 'pipeline', 'test-all')]
    [string]$Preset = 'quick-start',
    [string]$ConfigPath
)

. "$PSScriptRoot\wechat-pipeline.ps1"
. "$PSScriptRoot\wechat-status.ps1"

function Invoke-WechatRunPreset {
    [CmdletBinding()]
    param(
        [string]$Preset,
        [string]$ConfigPath
    )

    $summary = @{
        preset            = $Preset
        config_path       = $ConfigPath
        interface_version = 'v1'
    }

    switch ($Preset) {
        'quick-start' {
            $summary.status = Invoke-WechatStatus
        }
        'p2-fast-health' {
            $summary.status = Invoke-WechatStatus
            $summary.health = 'ready'
        }
        'pipeline' {
            $summary.pipeline = Invoke-WechatPipeline
        }
        'test-all' {
            $summary.pipeline = Invoke-WechatPipeline
            $summary.test_entry = 'scripts\\test-wechat-skill.ps1'
        }
    }

    return $summary
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WechatRunPreset -Preset $Preset -ConfigPath $ConfigPath | ConvertTo-Json -Depth 8
}

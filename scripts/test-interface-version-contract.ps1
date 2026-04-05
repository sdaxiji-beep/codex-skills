param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-gate.ps1"
. "$PSScriptRoot\wechat-pipeline.ps1"
. "$PSScriptRoot\test-common.ps1"
$gate = Invoke-WechatGate
$pipeline = Invoke-WechatPipeline
Assert-Equal $gate.interface_version 'v1' 'Gate interface version mismatch.'
Assert-True $gate.gate_declared 'Gate declared flag required.'
Assert-True $pipeline.gate.pipeline_declared 'Pipeline declared flag required.'
New-TestResult -Name 'interface-version-contract' -Data @{
    pass              = $true
    exit_code         = 0
    gate_declared     = $gate.gate_declared
    pipeline_declared = $pipeline.gate.pipeline_declared
    interface_version = $gate.interface_version
}

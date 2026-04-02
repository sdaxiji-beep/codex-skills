param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$raw = & "$PSScriptRoot\mcp-stage3-preflight.ps1" -AsJson 2>&1 | Out-String
$result = $raw | ConvertFrom-Json

Assert-True ($null -ne $result) 'stage3 preflight should return JSON'
Assert-True ($result.freeze_ok -eq $true) 'freeze baseline must be ok'
Assert-True ($result.safety_ok -eq $true) 'safety baseline must be ok'
Assert-True ($result.current_write_enableable -eq $false) 'current write path must remain non-enableable'
Assert-True ($result.simulated_write_enableable -eq $true) 'simulation should show enable path is viable when gates are open'
Assert-True ($result.ready_for_execution_phase -eq $true) 'preflight should mark stage3 execution phase as ready'

New-TestResult -Name 'mcp-stage3-preflight' -Data @{
    pass = $true
    exit_code = 0
    ready_for_execution_phase = $result.ready_for_execution_phase
}

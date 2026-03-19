param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$raw = & "$PSScriptRoot\mcp-v1-freeze.ps1" -AsJson 2>&1 | Out-String
$result = $raw | ConvertFrom-Json

Assert-True ($null -ne $result) 'freeze script should return JSON'
Assert-True ($result.ok -eq $true) 'freeze snapshot should be ok on stable baseline'
Assert-True ($result.stable -eq $true) 'readonly baseline should be stable in freeze snapshot'
Assert-True ($result.write_guarded -eq $true) 'write side should remain guarded in freeze snapshot'
Assert-True ($result.baseline.cloud_function_count -ge 1) 'cloud function count should be >= 1'

New-TestResult -Name 'mcp-v1-freeze' -Data @{
    pass = $true
    exit_code = 0
    ok = $result.ok
    stable = $result.stable
    write_guarded = $result.write_guarded
}

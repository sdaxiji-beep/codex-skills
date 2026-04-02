param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$raw = Invoke-WechatMcpSafetyCheck -AsJson 2>&1 | Out-String
$result = $raw | ConvertFrom-Json

Assert-True ($null -ne $result) 'MCP safety check should return a JSON result'
Assert-True ($result.readonly.stable -eq $true) 'readonly chain should be stable'
Assert-True ($result.write_gate.blocked -eq $true) 'write gate should remain blocked by default'
Assert-True ($result.write_readiness.can_enable -eq $false) 'write readiness should remain non-enableable by default'
Assert-True ($result.ok -eq $true) 'MCP safety summary should be OK under current baseline'

New-TestResult -Name 'wechat-entrypoint-mcp-safety-check' -Data @{
    pass = $true
    exit_code = 0
    ok = $result.ok
    readonly_stable = $result.readonly.stable
    write_blocked = $result.write_gate.blocked
}

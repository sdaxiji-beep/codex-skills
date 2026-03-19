param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$json = Invoke-WechatReadonlyCheck -AsJson 2>&1 | Out-String
Assert-NotEmpty $json 'Invoke-WechatReadonlyCheck should return JSON output'

$result = $json | ConvertFrom-Json
Assert-True ($result.stable -eq $true) 'entrypoint readonly check should be stable'
Assert-True ($result.status.readonly_mcp.health.cloud_list_exit_code -eq 0) 'cloud-list exit code should be 0'
Assert-True ($result.status.readonly_mcp.health.cloud_function_count -ge 1) 'cloud function count should be >= 1'

New-TestResult -Name 'wechat-entrypoint-readonly-check' -Data @{
    pass = $true
    exit_code = 0
    cloud_function_count = $result.status.readonly_mcp.health.cloud_function_count
}

param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$scriptPath = Join-Path $PSScriptRoot 'wechat-mcp-tool-boundary.ps1'
Assert-True (Test-Path $scriptPath) 'wechat-mcp-tool-boundary.ps1 should exist'

$profile = & $scriptPath -Operation describe_execution_profile | ConvertFrom-Json

Assert-Equal $profile.status 'success' 'Profile operation should return success'
Assert-Equal $profile.operation 'describe_execution_profile' 'Profile operation name should match request'
Assert-Equal $profile.interface_version 'mcp_tool_boundary_v1' 'Profile should expose interface version'
Assert-True ($profile.execution_profile.validate_operations -contains 'validate_page_bundle') 'Profile should declare validate operation coverage'
Assert-True ($profile.execution_profile.apply_operations -contains 'apply_page_bundle') 'Profile should declare apply operation coverage'
Assert-Equal $profile.execution_profile.apply_exit_code_mapping.'1' 'retryable_fail' 'Exit code 1 mapping should be retryable_fail'
Assert-Equal $profile.execution_profile.apply_exit_code_mapping.'2' 'hard_fail' 'Exit code 2 mapping should be hard_fail'
Assert-True ($profile.client_guidance.autonomous_retry_when -match 'retryable_fail') 'Profile should include autonomous retry guidance'
Assert-True ($profile.platform.supported_os -contains 'Windows') 'Profile should declare current supported OS baseline'

New-TestResult -Name 'wechat-mcp-tool-boundary-profile-contract' -Data @{
    pass = $true
    exit_code = 0
    interface_version = $profile.interface_version
}

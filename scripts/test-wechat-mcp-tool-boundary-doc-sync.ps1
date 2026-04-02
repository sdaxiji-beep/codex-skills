param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$boundaryScript = Join-Path $PSScriptRoot 'wechat-mcp-tool-boundary.ps1'
$readmePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'README.md'
$claudePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'CLAUDE.md'
$contractPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'MCP_BOUNDARY_CONTRACT.md'

Assert-True (Test-Path $boundaryScript) 'wechat-mcp-tool-boundary.ps1 should exist'
Assert-True (Test-Path $readmePath) 'README.md should exist'
Assert-True (Test-Path $claudePath) 'CLAUDE.md should exist'
Assert-True (Test-Path $contractPath) 'MCP_BOUNDARY_CONTRACT.md should exist'

$contract = & $boundaryScript -Operation describe_contract | ConvertFrom-Json
Assert-Equal $contract.status 'success' 'describe_contract should return success'

$profile = & $boundaryScript -Operation describe_execution_profile | ConvertFrom-Json
Assert-Equal $profile.status 'success' 'describe_execution_profile should return success'

$requiredOps = @(
    'describe_contract',
    'describe_execution_profile',
    'validate_page_bundle',
    'apply_page_bundle',
    'validate_component_bundle',
    'apply_component_bundle',
    'validate_app_json_patch',
    'apply_app_json_patch'
)

foreach ($op in $requiredOps) {
    Assert-True ($contract.supported_operations -contains $op) "Boundary contract should include operation: $op"
}

$readme = Get-Content -Path $readmePath -Raw -Encoding UTF8
$claude = Get-Content -Path $claudePath -Raw -Encoding UTF8
$contractDoc = Get-Content -Path $contractPath -Raw -Encoding UTF8

Assert-True ($readme -match 'describe_execution_profile') 'README should mention describe_execution_profile'
Assert-True ($claude -match 'describe_execution_profile') 'CLAUDE.md should mention describe_execution_profile'
Assert-True ($contractDoc -match 'describe_execution_profile') 'MCP boundary contract doc should mention describe_execution_profile'
Assert-True ($claude -match 'auto-retry only when') 'CLAUDE.md should include retry guidance for external clients'
Assert-Equal $profile.interface_version 'mcp_tool_boundary_v1' 'Execution profile should keep interface version'

New-TestResult -Name 'wechat-mcp-tool-boundary-doc-sync' -Data @{
    pass = $true
    exit_code = 0
    operations = $requiredOps.Count
    interface_version = $profile.interface_version
}

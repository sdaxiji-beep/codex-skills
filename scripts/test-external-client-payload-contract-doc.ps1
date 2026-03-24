param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$entrypointsPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'EXTERNAL_CLIENT_ENTRYPOINTS.md'
$contractPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'MCP_BOUNDARY_CONTRACT.md'

Assert-True (Test-Path $entrypointsPath) 'EXTERNAL_CLIENT_ENTRYPOINTS.md should exist'
Assert-True (Test-Path $contractPath) 'MCP_BOUNDARY_CONTRACT.md should exist'

$entrypoints = Get-Content -Path $entrypointsPath -Raw -Encoding UTF8
$contract = Get-Content -Path $contractPath -Raw -Encoding UTF8

foreach ($token in @('page_name', 'component_name', 'append_pages', 'current-project')) {
    Assert-True ($entrypoints.Contains($token)) "entrypoint doc should mention $token"
}

foreach ($token in @('page_name', 'component_name', 'append_pages')) {
    Assert-True ($contract.Contains($token)) "boundary contract doc should mention $token"
}

New-TestResult -Name 'external-client-payload-contract-doc' -Data @{
    pass = $true
    exit_code = 0
    required_tokens = 7
}

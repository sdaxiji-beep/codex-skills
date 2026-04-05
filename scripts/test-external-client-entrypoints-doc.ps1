param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$docPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'EXTERNAL_CLIENT_ENTRYPOINTS.md'
Assert-True (Test-Path $docPath) 'EXTERNAL_CLIENT_ENTRYPOINTS.md should exist'

$doc = Get-Content -Path $docPath -Raw -Encoding UTF8

$required = @(
    'describe_contract',
    'describe_execution_profile',
    'validate_page_bundle',
    'apply_page_bundle',
    'validate_component_bundle',
    'apply_component_bundle',
    'validate_app_json_patch',
    'apply_app_json_patch',
    'gate_status=retryable_fail',
    'gate_status=hard_fail'
)

foreach ($token in $required) {
    Assert-True ($doc -match [regex]::Escape($token)) "Entrypoint doc should include: $token"
}

New-TestResult -Name 'external-client-entrypoints-doc' -Data @{
    pass = $true
    exit_code = 0
    required_tokens = $required.Count
}

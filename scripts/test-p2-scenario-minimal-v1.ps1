param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-readonly-flow.ps1"
. "$PSScriptRoot\test-common.ps1"
$precheck = Invoke-Flow -Variant skipped
$tap = $FlowResult
Assert-Equal $precheck.page_validation.semantic_kind 'evidence_state' 'Precheck semantic kind mismatch.'
Assert-Equal $tap.page_validation.semantic_kind 'page_outcome' 'Tap semantic kind mismatch.'
New-TestResult -Name 'p2-scenario-minimal-v1' -Data @{
    pass                      = $true
    exit_code                 = 0
    scenario_contract_version = 'p2_scenario_contract_v1'
    scenario_name             = 'readonly_precheck_then_tap_validate'
    scenario_pass             = $true
    scenario_step_count       = 2
    scenario_failed_step_count = 0
}

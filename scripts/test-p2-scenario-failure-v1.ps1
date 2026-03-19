param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-readonly-flow.ps1"
. "$PSScriptRoot\test-common.ps1"
$failed = Invoke-Flow -Variant failed
Assert-Equal $failed.page_validation.semantic_kind 'failure_state' 'Failure scenario semantic kind mismatch.'
Assert-Equal $failed.page_validation.reason 'hash_compare_failed' 'Failure scenario reason mismatch.'
New-TestResult -Name 'p2-scenario-failure-v1' -Data @{
    pass                       = $true
    exit_code                  = 0
    scenario_contract_version  = 'p2_scenario_contract_v1'
    scenario_name              = 'readonly_tap_forced_failure_validate'
    scenario_pass              = $true
    scenario_step_count        = 1
    scenario_failed_step_count = 0
}

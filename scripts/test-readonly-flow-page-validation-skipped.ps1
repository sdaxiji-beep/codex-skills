param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-readonly-flow.ps1"
. "$PSScriptRoot\test-common.ps1"
$skipped = Invoke-Flow -Variant skipped
Assert-In $skipped.exit_code @(0,2,3) 'Exit code must be 0, 2 or 3.'
Assert-Equal $skipped.page_validation.page_state_class 'evidence_missing' 'Skipped page_state_class mismatch.'
Assert-In $skipped.page_signature.source @('automator_current_page_v1','page_state_class_mapping_v1') 'Unexpected signature source.'
New-TestResult -Name 'readonly-flow-page-validation-skipped' -Data @{
    pass                   = $true
    exit_code              = 0
    process_exit_code      = $skipped.exit_code
    page_validation_status = $skipped.page_validation.status
    page_validation_reason = $skipped.page_validation.reason
    result_level           = $skipped.page_validation.result_level
    raw_result_level       = $skipped.page_validation.raw_result_level
    result_level_policy    = $skipped.page_validation.result_level_policy
    page_state_class       = $skipped.page_validation.page_state_class
}

param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-readonly-flow.ps1"
. "$PSScriptRoot\test-common.ps1"
$skipped = Invoke-Flow -Variant skipped
Assert-Equal $skipped.page_validation.status 'skipped' 'Skipped variant expected.'
Assert-Equal $skipped.page_validation.result_level 'pass' 'Skipped variant should normalize to pass.'
Assert-Equal $skipped.page_validation.raw_result_level 'warn' 'Skipped raw result should remain warn.'
Assert-Equal $skipped.page_validation.result_level_policy 'normalize_skipped_capture_unavailable' 'Skipped normalization policy mismatch.'
New-TestResult -Name 'readonly-flow-page-validation-normalized-skipped' -Data @{
    pass                   = $true
    exit_code              = 0
    page_validation_status = $skipped.page_validation.status
    page_validation_reason = $skipped.page_validation.reason
    raw_result_level       = $skipped.page_validation.raw_result_level
    result_level           = $skipped.page_validation.result_level
    result_level_policy    = $skipped.page_validation.result_level_policy
}

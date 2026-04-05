param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-readonly-flow.ps1"
. "$PSScriptRoot\test-common.ps1"
$failed = Invoke-Flow -Variant failed
Assert-Equal $failed.page_validation.status 'failed' 'Expected failed status.'
Assert-Equal $failed.page_validation.reason 'hash_compare_failed' 'Expected hash_compare_failed.'
New-TestResult -Name 'readonly-flow-page-validation-failed' -Data @{
    pass                   = $true
    exit_code              = 0
    page_validation_status = $failed.page_validation.status
    page_validation_reason = $failed.page_validation.reason
    result_level           = $failed.page_validation.result_level
    raw_result_level       = $failed.page_validation.raw_result_level
    result_level_policy    = $failed.page_validation.result_level_policy
    page_state_class       = $failed.page_validation.page_state_class
}

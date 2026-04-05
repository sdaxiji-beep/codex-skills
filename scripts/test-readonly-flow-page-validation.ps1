param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
Assert-Equal $FlowResult.page_validation.status 'ok' 'Expected ok page validation.'
Assert-Equal $FlowResult.page_validation.reason 'image_unchanged' 'Expected image_unchanged reason.'
Assert-Equal $FlowResult.page_validation.result_level 'pass' 'Expected pass result level.'
New-TestResult -Name 'readonly-flow-page-validation' -Data @{
    pass                   = $true
    exit_code              = 0
    page_validation_status = $FlowResult.page_validation.status
    page_validation_reason = $FlowResult.page_validation.reason
    result_level           = $FlowResult.page_validation.result_level
    raw_result_level       = $FlowResult.page_validation.raw_result_level
    result_level_policy    = $FlowResult.page_validation.result_level_policy
    page_state_class       = $FlowResult.page_validation.page_state_class
}

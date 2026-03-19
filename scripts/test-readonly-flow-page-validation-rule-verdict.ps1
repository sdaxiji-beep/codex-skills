param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-readonly-flow.ps1"
. "$PSScriptRoot\test-common.ps1"
$ok = $FlowResult
$skipped = Invoke-Flow -Variant skipped
$failed = Invoke-Flow -Variant failed

Assert-Equal $ok.rule_verdict.rule_id 'page-outcome-required-v1' 'Unexpected rule id.'
Assert-True $ok.rule_verdict.rule_pass 'ok variant should pass rule.'
Assert-Equal $skipped.rule_verdict.rule_reason 'evidence_state_not_page_outcome' 'Skipped rule reason mismatch.'
Assert-Equal $failed.rule_verdict.rule_reason 'failure_state_not_page_outcome' 'Failed rule reason mismatch.'

New-TestResult -Name 'readonly-flow-page-validation-rule-verdict' -Data @{
    pass                 = $true
    exit_code            = 0
    rule_id              = $ok.rule_verdict.rule_id
    ok_rule_pass         = $ok.rule_verdict.rule_pass
    skipped_rule_reason  = $skipped.rule_verdict.rule_reason
    failed_rule_reason   = $failed.rule_verdict.rule_reason
}

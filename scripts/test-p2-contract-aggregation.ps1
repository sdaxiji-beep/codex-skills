param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\wechat-readonly-flow.ps1"
. "$PSScriptRoot\test-common.ps1"
$skipped = Invoke-Flow -Variant skipped
$failed = Invoke-Flow -Variant failed
$agg = @{
    contract_version = $FlowResult.contract_version
    semantic_kind_ok = $FlowResult.page_validation.semantic_kind
    semantic_kind_skipped = $skipped.page_validation.semantic_kind
    semantic_kind_failed = $failed.page_validation.semantic_kind
    rule_summary_status = $FlowResult.rule_summary.rule_summary_status
    total_rules = $FlowResult.rules_overview.total_rules
    signature_source = $FlowResult.page_signature.source
    signature_reason = $FlowResult.page_signature.reason
}
Assert-Equal $agg.contract_version 'page_validation_contract_v2' 'Unexpected p2_probe.contract_version.'
Assert-Equal $agg.semantic_kind_ok 'page_outcome' 'Unexpected p2_probe.semantic_kind_ok.'
Assert-In $agg.signature_source @('automator_current_page_v1','page_state_class_mapping_v1') 'Unexpected signature_source.'
New-TestResult -Name 'p2-contract-aggregation' -Data @{
    pass                = $true
    exit_code           = 0
    contract_version    = $agg.contract_version
    semantic_kind_ok    = $agg.semantic_kind_ok
    semantic_kind_skipped = $agg.semantic_kind_skipped
    semantic_kind_failed = $agg.semantic_kind_failed
    signature_source    = $agg.signature_source
}

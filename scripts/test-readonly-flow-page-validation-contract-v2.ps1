param([hashtable]$FlowResult,[hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
Assert-Equal $FlowResult.contract_version 'page_validation_contract_v2' 'Contract version mismatch.'
Assert-Equal $FlowResult.page_signature.contract_version 'page_signature_contract_v1' 'Page signature contract mismatch.'
Assert-In $FlowResult.page_signature.source @('automator_current_page_v1','page_state_class_mapping_v1') 'Unexpected signature_source.'
Assert-True ($FlowResult.page_signature.confidence -ge 0 -and $FlowResult.page_signature.confidence -le 1) 'Confidence must be in [0,1].'
Assert-True ($FlowResult.page_signature.candidates -is [System.Array]) 'Candidates must be an array.'
New-TestResult -Name 'readonly-flow-page-validation-contract-v2' -Data @{
    pass                       = $true
    exit_code                  = 0
    contract_version           = $FlowResult.contract_version
    semantic_kind_ok           = $FlowResult.page_validation.semantic_kind
    rule_summary_status        = $FlowResult.rule_summary.rule_summary_status
    rule_summary_reason        = $FlowResult.rule_summary.rule_summary_reason
    rule_summary_level         = $FlowResult.rule_summary.rule_summary_level
    total_rules                = $FlowResult.rules_overview.total_rules
    overall_rule_status        = $FlowResult.rules_overview.overall_rule_status
    page_candidate             = $FlowResult.page_candidate
    page_candidate_confidence  = $FlowResult.page_signature.confidence
    signature_source           = $FlowResult.page_signature.source
    signature_reason           = $FlowResult.page_signature.reason
}

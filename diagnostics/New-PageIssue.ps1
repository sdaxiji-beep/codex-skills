function New-PageIssue {
  param(
    [string]$IssueType,
    [string]$Source,
    [string]$PagePath,
    [string]$ProjectPath,
    [string]$Target = $null,
    [string]$Expected = "",
    [string]$Actual = "",
    [string]$RepairHint = ""
  )

  $severityMap = @{
    page_not_found            = "critical"; wrong_page_path          = "critical"
    page_blank                = "critical"; error_page_visible       = "critical"
    ast_parse_error           = "critical"; unauthorized_redirect    = "critical"
    missing_required_element  = "critical"; component_not_rendered   = "critical"
    empty_list_render         = "critical"; required_text_missing    = "critical"
    missing_required_button   = "critical"; missing_page_entry       = "critical"
    unexpected_error_toast    = "critical"; tabbar_item_missing      = "critical"
    data_not_bound            = "critical"; bundle_validation_failed = "critical"
    generation_gate_rejected  = "critical"; missing_navigation_bar   = "warning"
    stale_placeholder_visible = "warning";  page_load_timeout        = "warning"
    text_encoding_garbled     = "critical"
  }

  $retryableMap = @{
    page_not_found        = $false
    unauthorized_redirect = $false
    ast_parse_error       = $false
  }

  $severity = if ($severityMap.ContainsKey($IssueType)) { $severityMap[$IssueType] } else { "critical" }
  $retryable = if ($retryableMap.ContainsKey($IssueType)) { $false } else { $true }
  $issueId   = "$IssueType|$PagePath|$Source"

  return [PSCustomObject]@{
    issue_id     = $issueId
    status       = "failed"
    issue_type   = $IssueType
    target       = $Target
    expected     = $Expected
    actual       = $Actual
    severity     = $severity
    source       = $Source
    page_path    = $PagePath
    project_path = $ProjectPath
    repair_hint  = $RepairHint
    retryable    = $retryable
    timestamp    = (Get-Date -Format "o")
  }
}

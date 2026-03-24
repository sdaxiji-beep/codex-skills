function Invoke-DetectorDecision {
  param(
    [Parameter(Mandatory = $true)]
    $DetectorResult,
    [double]$RepairConfidenceThreshold = 0.50
  )

  if ($null -eq $DetectorResult) {
    throw "detector result is null"
  }

  if ($null -eq $DetectorResult.issue) {
    throw "detector result missing issue"
  }

  $issue = $DetectorResult.issue
  $status = [string]$issue.status
  $severity = [string]$issue.severity
  $retryable = [bool]$issue.retryable
  $confidence = if ($issue.PSObject.Properties['detector_confidence']) {
    [double]$issue.detector_confidence
  } else {
    1.0
  }

  if ($status -eq 'passed') {
    return [PSCustomObject]@{
      action = 'done'
      reason = 'issue_passed'
      should_repair = $false
      requires_manual = $false
      confidence = $confidence
      issue_id = [string]$issue.issue_id
    }
  }

  if (-not $retryable) {
    return [PSCustomObject]@{
      action = 'halt_manual'
      reason = 'non_retryable_issue'
      should_repair = $false
      requires_manual = $true
      confidence = $confidence
      issue_id = [string]$issue.issue_id
    }
  }

  if ($severity -eq 'critical') {
    if ($confidence -ge $RepairConfidenceThreshold) {
      return [PSCustomObject]@{
        action = 'repair'
        reason = 'critical_retryable_with_sufficient_confidence'
        should_repair = $true
        requires_manual = $false
        confidence = $confidence
        issue_id = [string]$issue.issue_id
      }
    }

    return [PSCustomObject]@{
      action = 'verify_then_repair'
      reason = 'critical_retryable_low_confidence'
      should_repair = $false
      requires_manual = $false
      confidence = $confidence
      issue_id = [string]$issue.issue_id
    }
  }

  if ($severity -eq 'warning') {
    return [PSCustomObject]@{
      action = 'observe'
      reason = 'warning_deferred'
      should_repair = $false
      requires_manual = $false
      confidence = $confidence
      issue_id = [string]$issue.issue_id
    }
  }

  return [PSCustomObject]@{
    action = 'log_only'
    reason = 'non_critical_or_info'
    should_repair = $false
    requires_manual = $false
    confidence = $confidence
    issue_id = [string]$issue.issue_id
  }
}

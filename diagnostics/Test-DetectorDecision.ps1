. "$PSScriptRoot\Invoke-DetectorDecision.ps1"

function Assert-Equal {
  param(
    [Parameter(Mandatory = $true)]$Actual,
    [Parameter(Mandatory = $true)]$Expected,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if ($Actual -ne $Expected) {
    throw "assert failed: $Message (actual=$Actual expected=$Expected)"
  }
}

Write-Host "[test] Start DetectorDecision minimal check..." -ForegroundColor Cyan

# case 1: passed
$res1 = Invoke-DetectorDecision -DetectorResult ([PSCustomObject]@{
  issue = [PSCustomObject]@{
    issue_id = 'passed|a|screenshot'
    status = 'passed'
    severity = 'info'
    retryable = $false
    detector_confidence = 0.55
  }
})
Assert-Equal -Actual $res1.action -Expected 'done' -Message 'passed should be done'

# case 2: critical retryable high confidence
$res2 = Invoke-DetectorDecision -DetectorResult ([PSCustomObject]@{
  issue = [PSCustomObject]@{
    issue_id = 'missing_required_element|a|automator'
    status = 'failed'
    severity = 'critical'
    retryable = $true
    detector_confidence = 0.90
  }
})
Assert-Equal -Actual $res2.action -Expected 'repair' -Message 'critical high confidence should repair'

# case 3: critical retryable low confidence
$res3 = Invoke-DetectorDecision -DetectorResult ([PSCustomObject]@{
  issue = [PSCustomObject]@{
    issue_id = 'error_page_visible|a|screenshot'
    status = 'failed'
    severity = 'critical'
    retryable = $true
    detector_confidence = 0.20
  }
})
Assert-Equal -Actual $res3.action -Expected 'verify_then_repair' -Message 'critical low confidence should verify'

# case 4: non-retryable
$res4 = Invoke-DetectorDecision -DetectorResult ([PSCustomObject]@{
  issue = [PSCustomObject]@{
    issue_id = 'page_not_found|a|automator'
    status = 'failed'
    severity = 'critical'
    retryable = $false
    detector_confidence = 0.90
  }
})
Assert-Equal -Actual $res4.action -Expected 'halt_manual' -Message 'non-retryable should halt'

Write-Host "[test] PASS: decision routing is consistent" -ForegroundColor Green
exit 0

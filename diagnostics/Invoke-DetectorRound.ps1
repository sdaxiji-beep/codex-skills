. "$PSScriptRoot\Invoke-DetectorBridge.ps1"
. "$PSScriptRoot\Invoke-DetectorDecision.ps1"
. "$PSScriptRoot\Invoke-ProjectHealthOverlay.ps1"
. "$PSScriptRoot\Invoke-CompileHealthOverlay.ps1"
. "$PSScriptRoot\Invoke-ConsoleErrorOverlay.ps1"
. "$PSScriptRoot\Invoke-CollectConsoleLog.ps1"
. "$PSScriptRoot\Write-DiagnosticsMetrics.ps1"

function Invoke-DetectorRound {
  param(
    [Parameter(Mandatory = $true)][string]$PagePath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$PreferredDetector = "automator",
    [double]$RepairConfidenceThreshold = 0.50,
    [bool]$EnforcePageRecognition = $true,
    [switch]$CollectConsoleLog
  )

  $detectorResult = Invoke-DetectorBridge `
    -PagePath $PagePath `
    -ProjectPath $ProjectPath `
    -PreferredDetector $PreferredDetector

  $overlayIssue = Invoke-ProjectHealthOverlay `
    -PagePath $PagePath `
    -ProjectPath $ProjectPath

  if ($EnforcePageRecognition -and
      $PreferredDetector -eq "automator" -and
      $detectorResult.detector_status -eq "primary_failed_fallback_used" -and
      $detectorResult.issue.status -eq "passed") {
    $pageRecognitionIssue = New-PageIssue `
      -IssueType "page_not_found" `
      -Source "overlay" `
      -PagePath $PagePath `
      -ProjectPath $ProjectPath `
      -Target $PagePath `
      -Expected "automator page path recognized for target project" `
      -Actual "automator unavailable; screenshot fallback cannot prove exact route" `
      -RepairHint "restore automator route verification, then rerun detection"
    $pageRecognitionIssue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.98 -Force

    $detectorResult = [PSCustomObject]@{
      issue = $pageRecognitionIssue
      detector_status = "page_recognition_unverified"
      detectors_tried = @($detectorResult.detectors_tried + @("overlay_page_recognition"))
    }
  }

  $consoleCollection = $null
  if ($CollectConsoleLog) {
    $consoleCollection = Invoke-CollectConsoleLog
  }

  $consoleLogPath = if ($CollectConsoleLog -and $consoleCollection -and $consoleCollection.output_path) {
    [string]$consoleCollection.output_path
  } else {
    ""
  }

  $consoleIssue = Invoke-ConsoleErrorOverlay `
    -PagePath $PagePath `
    -ProjectPath $ProjectPath `
    -ConsoleLogPath $consoleLogPath

  $compileIssue = Invoke-CompileHealthOverlay `
    -PagePath $PagePath `
    -ProjectPath $ProjectPath

  if ($detectorResult.issue.status -eq "passed" -and $consoleIssue.status -ne "passed") {
    $detectorResult = [PSCustomObject]@{
      issue = $consoleIssue
      detector_status = "overlay_console_detected_issue"
      detectors_tried = @($detectorResult.detectors_tried + @("overlay_console"))
    }
  }
  elseif ($detectorResult.issue.status -eq "passed" -and $compileIssue.status -ne "passed") {
    $detectorResult = [PSCustomObject]@{
      issue = $compileIssue
      detector_status = "overlay_compile_detected_issue"
      detectors_tried = @($detectorResult.detectors_tried + @("overlay_compile"))
    }
  }
  elseif ($detectorResult.issue.status -eq "passed" -and $overlayIssue.status -ne "passed") {
    $detectorResult = [PSCustomObject]@{
      issue = $overlayIssue
      detector_status = "overlay_detected_issue"
      detectors_tried = @($detectorResult.detectors_tried + @("overlay"))
    }
  }

  $decision = Invoke-DetectorDecision `
    -DetectorResult $detectorResult `
    -RepairConfidenceThreshold $RepairConfidenceThreshold

  $issueTypeLabel = if ($detectorResult.issue -and $detectorResult.issue.issue_type) {
    [string]$detectorResult.issue.issue_type
  } else {
    'passed'
  }

  $issueSourceLabel = if ($detectorResult.issue -and $detectorResult.issue.source) {
    [string]$detectorResult.issue.source
  } else {
    'unknown'
  }

  $metrics = [pscustomobject]@{
    source = 'detector_round'
    page_path = $PagePath
    project_path = $ProjectPath
    preferred_detector = $PreferredDetector
    collect_console_log = [bool]$CollectConsoleLog
    enforce_page_recognition = [bool]$EnforcePageRecognition
    detector_status = [string]$detectorResult.detector_status
    detector_status_counts = @{
      ([string]$detectorResult.detector_status) = 1
    }
    detectors_tried = @($detectorResult.detectors_tried)
    issue_type_counts = @{
      $issueTypeLabel = 1
    }
    issue_source_counts = @{
      $issueSourceLabel = 1
    }
    decision_action_counts = @{
      ([string]$decision.action) = 1
    }
    console_overlay_hit = [bool]($consoleIssue.status -ne 'passed')
    compile_overlay_hit = [bool]($compileIssue.status -ne 'passed')
    round_status = if ($decision.action -eq 'done') { 'passed' } else { 'needs_action' }
    decision_action = [string]$decision.action
    decision_reason = [string]$decision.reason
    decision_confidence = $decision.confidence
    issue_status = [string]$detectorResult.issue.status
    timestamp = (Get-Date -Format "o")
  }

  Invoke-WriteDiagnosticsMetrics -Metrics $metrics | Out-Null

  return [PSCustomObject]@{
    detector_result = $detectorResult
    overlay_issue = $overlayIssue
    console_collection = $consoleCollection
    console_issue = $consoleIssue
    compile_issue = $compileIssue
    decision = $decision
    round_status = if ($decision.action -eq 'done') { 'passed' } else { 'needs_action' }
    timestamp = (Get-Date -Format "o")
  }
}

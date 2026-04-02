. "$PSScriptRoot\screenshot\Invoke-ScreenshotFallback.ps1"
. "$PSScriptRoot\New-PageIssue.ps1"
. "$PSScriptRoot\Invoke-AutomatorCheck.ps1"

function Invoke-DetectorBridge {
  param(
    [string]$PagePath,
    [string]$ProjectPath,
    [string]$PreferredDetector = "automator"
  )

  $tried = @()

  # --- automator route ---
  if ($PreferredDetector -eq "automator") {
    $tried += "automator"
    Write-Host "[detector-bridge] Try automator..."

    try {
      # Placeholder automator entrypoint. If not implemented yet,
      # this throws and the bridge falls back to screenshot.
      $issue = Invoke-AutomatorCheck `
        -PagePath    $PagePath `
        -ProjectPath $ProjectPath

      $status = if ($issue.status -eq "passed") {
        "primary_passed"
      } else {
        "primary_detected_issue"
      }

      Write-Host "[detector-bridge] automator done, status=$status"
      return [PSCustomObject]@{
        issue           = $issue
        detector_status = $status
        detectors_tried = $tried
      }
    }
    catch {
      Write-Warning "[detector-bridge] automator failed: $_ ; switching to screenshot fallback"
    }
  }

  # --- screenshot fallback route ---
  $tried += "screenshot"
  Write-Host "[detector-bridge] Try screenshot..."

  try {
    $issue = Invoke-ScreenshotFallback `
      -PagePath    $PagePath `
      -ProjectPath $ProjectPath

    $fallbackStatus = if ($PreferredDetector -eq "automator") {
      "primary_failed_fallback_used"
    } else {
      "preferred_detector_used"
    }

    Write-Host "[detector-bridge] screenshot done, status=$($issue.status)"
    return [PSCustomObject]@{
      issue           = $issue
      detector_status = $fallbackStatus
      detectors_tried = $tried
    }
  }
  catch {
    Write-Warning "[detector-bridge] screenshot also failed: $_"

    $issue = New-PageIssue `
      -IssueType   "page_load_timeout" `
      -Source      "screenshot" `
      -PagePath    $PagePath `
      -ProjectPath $ProjectPath `
      -Expected    "at least one detector returns a result" `
      -Actual      "automator and screenshot both failed" `
      -RepairHint  "check whether DevTools is running and the detector path is usable"

    return [PSCustomObject]@{
      issue           = $issue
      detector_status = "fallback_failed"
      detectors_tried = $tried
    }
  }
}

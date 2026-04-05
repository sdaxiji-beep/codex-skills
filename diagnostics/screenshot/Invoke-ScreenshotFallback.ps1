. "$PSScriptRoot\Invoke-ScreenshotCapture.ps1"
. "$PSScriptRoot\Invoke-OcrCheck.ps1"
. "$PSScriptRoot\Invoke-VisualCheck.ps1"
. "$PSScriptRoot\..\New-PageIssue.ps1"

function Invoke-ScreenshotFallback {
  param(
    [string]$PagePath,
    [string]$ProjectPath,
    [string]$CaptureDir = "$PSScriptRoot\captures"
  )

  Write-Host "[screenshot-fallback] automator unavailable, starting visual screenshot check..."

  try {
    $path = Invoke-ScreenshotCapture -OutputDir $CaptureDir
    Write-Host "[screenshot-fallback] capture complete: $path"

    $visualIssue = Invoke-VisualCheck `
      -ScreenshotPath $path `
      -PagePath       $PagePath `
      -ProjectPath    $ProjectPath

    if ($visualIssue.status -ne 'passed') {
      $visualIssue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.6 -Force
      $visualIssue | Add-Member -NotePropertyName ocr_status -NotePropertyValue 'skipped_due_to_visual_failure' -Force
      Write-Host "[screenshot-fallback] result: $($visualIssue.status) / $($visualIssue.issue_type)"
      return $visualIssue
    }

    try {
      $ocrIssue = Invoke-OcrCheck `
        -ScreenshotPath $path `
        -PagePath       $PagePath `
        -ProjectPath    $ProjectPath

      if ($ocrIssue.status -ne 'passed') {
        $ocrIssue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.72 -Force
        $ocrIssue | Add-Member -NotePropertyName ocr_status -NotePropertyValue 'matched_blocker_text' -Force
        Write-Host "[screenshot-fallback] result: $($ocrIssue.status) / $($ocrIssue.issue_type)"
        return $ocrIssue
      }

      $visualIssue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.68 -Force
      $visualIssue | Add-Member -NotePropertyName ocr_status -NotePropertyValue 'no_blocker_text_detected' -Force
      Write-Host "[screenshot-fallback] result: $($visualIssue.status) / $($visualIssue.issue_type)"
      return $visualIssue
    }
    catch {
      Write-Warning "[screenshot-fallback] OCR check unavailable: $_"
      $visualIssue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.55 -Force
      $visualIssue | Add-Member -NotePropertyName ocr_status -NotePropertyValue 'unavailable' -Force
      Write-Host "[screenshot-fallback] result: $($visualIssue.status) / $($visualIssue.issue_type)"
      return $visualIssue
    }
  }
  catch {
    Write-Warning "[screenshot-fallback] flow exception: $_"
    $issue = New-PageIssue `
      -IssueType   "page_load_timeout" `
      -Source      "screenshot" `
      -PagePath    $PagePath `
      -ProjectPath $ProjectPath `
      -Expected    "capture and visual check should complete" `
      -Actual      "flow exception: $_" `
      -RepairHint  "confirm DevTools is open and screenshot permissions are available"
    $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.2 -Force
    return $issue
  }
}

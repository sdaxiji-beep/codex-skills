. "$PSScriptRoot\Invoke-ScreenshotCapture.ps1"
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

    $issue = Invoke-VisualCheck `
      -ScreenshotPath $path `
      -PagePath       $PagePath `
      -ProjectPath    $ProjectPath
    $confidence = if ($issue.status -eq 'passed') { 0.55 } else { 0.6 }
    $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue $confidence -Force

    Write-Host "[screenshot-fallback] result: $($issue.status) / $($issue.issue_type)"
    return $issue
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

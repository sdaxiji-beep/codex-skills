. "$PSScriptRoot\..\New-PageIssue.ps1"

function Invoke-VisualCheck {
  param(
    [string]$ScreenshotPath,
    [string]$PagePath,
    [string]$ProjectPath
  )

  if (-not (Test-Path $ScreenshotPath)) {
    throw "Screenshot file not found: $ScreenshotPath"
  }

  Add-Type -AssemblyName System.Drawing

  # Sample the center 200x200 region.
  $bmp    = [System.Drawing.Bitmap]::FromFile($ScreenshotPath)
  $cx     = [int]($bmp.Width / 2)
  $cy     = [int]($bmp.Height / 2)
  $startX = [Math]::Max(0, $cx - 100)
  $startY = [Math]::Max(0, $cy - 100)
  $endX   = [Math]::Min($bmp.Width,  $startX + 200)
  $endY   = [Math]::Min($bmp.Height, $startY + 200)

  $total = 0
  $white = 0
  $dark  = 0
  $red   = 0

  for ($x = $startX; $x -lt $endX; $x++) {
    for ($y = $startY; $y -lt $endY; $y++) {
      $c = $bmp.GetPixel($x, $y)
      $total++
      if ($c.R -gt 240 -and $c.G -gt 240 -and $c.B -gt 240) { $white++ }
      if ($c.R -lt 15 -and $c.G -lt 15 -and $c.B -lt 15) { $dark++ }
      if ($c.R -gt 180 -and $c.G -lt 80 -and $c.B -lt 80) { $red++ }
    }
  }

  $bmp.Dispose()

  if ($total -eq 0) {
    throw "Sample region has zero pixels: $ScreenshotPath"
  }

  # Rule 1: page_blank
  if (($white / $total) -gt 0.95) {
    return New-PageIssue `
      -IssueType   "page_blank" `
      -Source      "screenshot" `
      -PagePath    $PagePath `
      -ProjectPath $ProjectPath `
      -Expected    "main content should be visible" `
      -Actual      "center region is $([Math]::Round(($white / $total) * 100))% white" `
      -RepairHint  "page did not render; check onLoad errors or hidden root node conditions"
  }

  # Rule 2: error_page_visible
  if (($dark / $total) -gt 0.90) {
    return New-PageIssue `
      -IssueType   "error_page_visible" `
      -Source      "screenshot" `
      -PagePath    $PagePath `
      -ProjectPath $ProjectPath `
      -Expected    "simulator content should be visible" `
      -Actual      "center region is almost fully dark" `
      -RepairHint  "confirm DevTools is fully loaded and the simulator is visible"
  }

  # Rule 3: unexpected_error_toast
  if (($red / $total) -gt 0.05) {
    return New-PageIssue `
      -IssueType   "unexpected_error_toast" `
      -Source      "screenshot" `
      -PagePath    $PagePath `
      -ProjectPath $ProjectPath `
      -Expected    "no obvious error-color block" `
      -Actual      "center region contains a strong red area that looks like an error toast" `
      -RepairHint  "check failed requests or business logic that triggered an error prompt"
  }

  return [PSCustomObject]@{
    issue_id     = "passed|$PagePath|screenshot"
    status       = "passed"
    issue_type   = $null
    target       = $null
    expected     = "page visually acceptable"
    actual       = "no critical visual anomaly detected"
    severity     = "info"
    source       = "screenshot"
    page_path    = $PagePath
    project_path = $ProjectPath
    repair_hint  = ""
    retryable    = $false
    timestamp    = (Get-Date -Format "o")
  }
}

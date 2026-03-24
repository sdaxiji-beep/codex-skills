. "$PSScriptRoot\New-PageIssue.ps1"

function Test-TextLooksGarbled {
  param([string]$Text)

  if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
  if ($Text -match '%[0-9A-Fa-f]{2}%[0-9A-Fa-f]{2}') { return $true }
  if ($Text.Contains([string][char]0xFFFD)) { return $true } # replacement char
  if ($Text -match '\?$') { return $true } # suspicious broken tail
  return $false
}

function Invoke-ProjectHealthOverlay {
  param(
    [Parameter(Mandatory = $true)][string]$PagePath,
    [Parameter(Mandatory = $true)][string]$ProjectPath
  )

  $appJsonPath = Join-Path $ProjectPath "app.json"
  if (-not (Test-Path $appJsonPath)) {
    return [PSCustomObject]@{
      issue_id = "passed|$PagePath|overlay"
      status = "passed"
      issue_type = $null
      target = $null
      expected = "app.json present"
      actual = "app.json not present, overlay skipped"
      severity = "info"
      source = "overlay"
      page_path = $PagePath
      project_path = $ProjectPath
      repair_hint = ""
      retryable = $false
      timestamp = (Get-Date -Format "o")
      detector_confidence = 1.0
    }
  }

  $obj = $null
  try {
    $obj = Get-Content $appJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
  }
  catch {
    return New-PageIssue `
      -IssueType "text_encoding_garbled" `
      -Source "overlay" `
      -PagePath $PagePath `
      -ProjectPath $ProjectPath `
      -Target "app.json" `
      -Expected "valid UTF-8 readable UI text" `
      -Actual ("app.json parse failed: " + $_.Exception.Message) `
      -RepairHint "rewrite app.json with clean UTF-8 text values"
  }

  $samples = @()
  if ($obj.window -and $obj.window.navigationBarTitleText) {
    $samples += [string]$obj.window.navigationBarTitleText
  }
  if ($obj.tabBar -and $obj.tabBar.list) {
    foreach ($item in @($obj.tabBar.list)) {
      if ($item.text) { $samples += [string]$item.text }
    }
  }

  $bad = $samples | Where-Object { Test-TextLooksGarbled -Text $_ }
  if (@($bad).Count -gt 0) {
    return New-PageIssue `
      -IssueType "text_encoding_garbled" `
      -Source "overlay" `
      -PagePath $PagePath `
      -ProjectPath $ProjectPath `
      -Target "app.json.ui_text" `
      -Expected "readable UTF-8 labels" `
      -Actual ("suspicious text: " + (($bad | Select-Object -First 3) -join " | ")) `
      -RepairHint "normalize navigationBarTitleText and tabBar labels to clean UTF-8 text"
  }

  return [PSCustomObject]@{
    issue_id = "passed|$PagePath|overlay"
    status = "passed"
    issue_type = $null
    target = $null
    expected = "readable UTF-8 labels"
    actual = "overlay checks passed"
    severity = "info"
    source = "overlay"
    page_path = $PagePath
    project_path = $ProjectPath
    repair_hint = ""
    retryable = $false
    timestamp = (Get-Date -Format "o")
    detector_confidence = 1.0
  }
}

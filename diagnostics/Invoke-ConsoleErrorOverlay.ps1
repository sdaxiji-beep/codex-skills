. "$PSScriptRoot\New-PageIssue.ps1"

function Invoke-ConsoleErrorOverlay {
  param(
    [Parameter(Mandatory = $true)][string]$PagePath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$ConsoleLogPath = ""
  )

  if ([string]::IsNullOrWhiteSpace($ConsoleLogPath)) {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $ConsoleLogPath = Join-Path $repoRoot "artifacts\wechat-devtools\console\latest.log"
  }

  if (-not (Test-Path $ConsoleLogPath)) {
    return [PSCustomObject]@{
      issue_id = "passed|$PagePath|overlay_console"
      status = "passed"
      issue_type = $null
      target = $ConsoleLogPath
      expected = "console log available"
      actual = "console log not found, skip"
      severity = "info"
      source = "overlay"
      page_path = $PagePath
      project_path = $ProjectPath
      repair_hint = ""
      retryable = $false
      timestamp = (Get-Date -Format "o")
      detector_confidence = 0.7
    }
  }

  $raw = Get-Content -Path $ConsoleLogPath -Raw -Encoding UTF8
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return [PSCustomObject]@{
      issue_id = "passed|$PagePath|overlay_console"
      status = "passed"
      issue_type = $null
      target = $ConsoleLogPath
      expected = "console log has content"
      actual = "empty console log"
      severity = "info"
      source = "overlay"
      page_path = $PagePath
      project_path = $ProjectPath
      repair_hint = ""
      retryable = $false
      timestamp = (Get-Date -Format "o")
      detector_confidence = 0.75
    }
  }

  $normalized = $PagePath.TrimStart('/').Trim()
  $wxmlRef = "./$normalized.wxml"
  $noisePatterns = @(
    '游客模式',
    'wx\.operateWXData',
    'webapi_getwxaasyncsecinfo:fail',
    'getSystemInfo API',
    'HarmonyOS',
    'source:\s*devtools://devtools/bundled/ui/ActionRegistry\.js',
    'console\.assert',
    'USB: usb_'
  )
  $isNoiseOnly = $true
  foreach ($line in @($raw -split "`r?`n")) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    $matched = $false
    foreach ($pattern in $noisePatterns) {
      if ($line -match $pattern) {
        $matched = $true
        break
      }
    }
    if (-not $matched) {
      $isNoiseOnly = $false
      break
    }
  }

  if ($isNoiseOnly) {
    return [PSCustomObject]@{
      issue_id = "passed|$PagePath|overlay_console"
      status = "passed"
      issue_type = $null
      target = $ConsoleLogPath
      expected = "no blocking compile/runtime issue in console"
      actual = "noise-only console patterns detected and ignored"
      severity = "info"
      source = "overlay"
      page_path = $PagePath
      project_path = $ProjectPath
      repair_hint = ""
      retryable = $false
      timestamp = (Get-Date -Format "o")
      detector_confidence = 0.95
    }
  }

  $compileHit = ($raw -match '\[ WXML 文件编译错误\]' -or $raw -match 'WXML.*compile')
  $targetHit = ($raw -match [regex]::Escape($wxmlRef) -or $raw -match [regex]::Escape("$normalized.wxml"))
  $tokenHit = ($raw -match 'unexpected token' -or $raw -match 'Bad value with message')

  if ($compileHit -and ($targetHit -or $tokenHit)) {
    $actual = "console compile error detected for $normalized"
    if ($raw -match 'unexpected token [`''""]?([^`''""\r\n]+)') {
      $actual = "console compile error: unexpected token '$($matches[1])' in $normalized"
    }

    $issue = New-PageIssue `
      -IssueType "generation_gate_rejected" `
      -Source "overlay" `
      -PagePath $PagePath `
      -ProjectPath $ProjectPath `
      -Target "$normalized.wxml" `
      -Expected "no WXML compile error in console" `
      -Actual $actual `
      -RepairHint "fix WXML expression syntax at reported line and recompile"
    $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.99 -Force
    return $issue
  }

  if ($raw -match '__route__ is not defined') {
    $issue = New-PageIssue `
      -IssueType "error_page_visible" `
      -Source "overlay" `
      -PagePath $PagePath `
      -ProjectPath $ProjectPath `
      -Target $normalized `
      -Expected "__route__ is defined" `
      -Actual "render layer reports __route__ is not defined" `
      -RepairHint "fix preceding compile errors first, then rerender page"
    $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.96 -Force
    return $issue
  }

  return [PSCustomObject]@{
    issue_id = "passed|$PagePath|overlay_console"
    status = "passed"
    issue_type = $null
    target = $ConsoleLogPath
    expected = "no compile/runtime blocker in console"
    actual = "no blocker matched"
    severity = "info"
    source = "overlay"
    page_path = $PagePath
    project_path = $ProjectPath
    repair_hint = ""
    retryable = $false
    timestamp = (Get-Date -Format "o")
    detector_confidence = 0.85
  }
}

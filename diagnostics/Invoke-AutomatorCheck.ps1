. "$PSScriptRoot\New-PageIssue.ps1"

function Invoke-AutomatorCheck {
  param(
    [string]$PagePath,
    [string]$ProjectPath,
    [int]   $AutoPort = 9420
  )

  Write-Host "[automator-check] start, port=$AutoPort"

  # Step 1: check port reachable
  $portOpen = $false
  try {
    $tcp   = New-Object System.Net.Sockets.TcpClient
    $async = $tcp.BeginConnect("127.0.0.1", $AutoPort, $null, $null)
    $ok    = $async.AsyncWaitHandle.WaitOne(3000)
    if ($ok -and $tcp.Connected) { $portOpen = $true }
    $tcp.Close()
  } catch { }

  if (-not $portOpen) {
    throw "automator port $AutoPort unreachable"
  }

  Write-Host "[automator-check] port reachable, running probe..."

  # Step 2: run probe-automator.js
  $prevAutoPort = $env:WECHAT_AUTOMATOR_PORT
  $prevDevtoolsPort = $env:WECHAT_DEVTOOLS_PORT
  $env:WECHAT_AUTOMATOR_PORT = [string]$AutoPort
  $env:WECHAT_DEVTOOLS_PORT  = [string]$AutoPort

  try {
    $raw = & node "$PSScriptRoot\..\scripts\probe-automator.js" 2>&1

    if ($LASTEXITCODE -ne 0) {
      throw "probe exited $LASTEXITCODE : $raw"
    }

    $jsonLine = ($raw | ForEach-Object { "$_".Trim() } | Where-Object { $_ -match '^\{' } | Select-Object -Last 1)
    if ([string]::IsNullOrWhiteSpace($jsonLine)) {
      throw "probe returned no JSON payload: $raw"
    }
    $probe = $jsonLine | ConvertFrom-Json -ErrorAction Stop

  } catch {
    throw "probe failed: $_"
  } finally {
    if ($null -eq $prevAutoPort) {
      Remove-Item Env:WECHAT_AUTOMATOR_PORT -ErrorAction SilentlyContinue
    } else {
      $env:WECHAT_AUTOMATOR_PORT = $prevAutoPort
    }

    if ($null -eq $prevDevtoolsPort) {
      Remove-Item Env:WECHAT_DEVTOOLS_PORT -ErrorAction SilentlyContinue
    } else {
      $env:WECHAT_DEVTOOLS_PORT = $prevDevtoolsPort
    }
  }

  if ($null -eq $probe) {
    throw "probe returned null"
  }

  # Step 3: translate probe output to PageIssue

  # wrong page path
  if ($probe.path -and $probe.path -ne $PagePath) {
    return New-PageIssue `
      -IssueType   "wrong_page_path" `
      -Source      "automator" `
      -PagePath    $PagePath `
      -ProjectPath $ProjectPath `
      -Expected    $PagePath `
      -Actual      $probe.path `
      -RepairHint  "current page path mismatch, check routing or app.json pages config"
  }

  # issues array: map known issue prefixes
  if ($probe.issues -and $probe.issues.Count -gt 0) {
    $first = $probe.issues[0]
    if ($first -match '^missing_required_element:(.+)$') {
      $target = $matches[1]
      $issue = New-PageIssue `
        -IssueType   "missing_required_element" `
        -Source      "automator" `
        -PagePath    $PagePath `
        -ProjectPath $ProjectPath `
        -Target      $target `
        -Expected    "element present" `
        -Actual      "missing_required_element:$target" `
        -RepairHint  "check element rendering conditions and selector mapping"
      $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.9 -Force
      return $issue
    }

    if ($first -match '^missing_required_data:(.+)$') {
      $target = $matches[1]
      $issue = New-PageIssue `
        -IssueType   "data_not_bound" `
        -Source      "automator" `
        -PagePath    $PagePath `
        -ProjectPath $ProjectPath `
        -Target      $target `
        -Expected    "required data key present and bound" `
        -Actual      "missing_required_data:$target" `
        -RepairHint  "ensure data key is populated before render"
      $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.9 -Force
      return $issue
    }

    if ($first -match '^unsupported_rule:(.+)$') {
      $target = $matches[1]
      $issue = New-PageIssue `
        -IssueType   "bundle_validation_failed" `
        -Source      "automator" `
        -PagePath    $PagePath `
        -ProjectPath $ProjectPath `
        -Target      $target `
        -Expected    "supported validation rule syntax" `
        -Actual      "unsupported_rule:$target" `
        -RepairHint  "update validation rule syntax to supported patterns"
      $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.8 -Force
      return $issue
    }

    $issue = New-PageIssue `
      -IssueType   "generation_gate_rejected" `
      -Source      "automator" `
      -PagePath    $PagePath `
      -ProjectPath $ProjectPath `
      -Target      $first `
      -Expected    "no semantic issues from probe" `
      -Actual      "probe_issue:$first" `
      -RepairHint  "check probe issues and align page semantics"
    $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.8 -Force
    return $issue
  }

  # is_valid = false
  if ($probe.is_valid -eq $false) {
    $issue = New-PageIssue `
      -IssueType   "error_page_visible" `
      -Source      "automator" `
      -PagePath    $PagePath `
      -ProjectPath $ProjectPath `
      -Expected    "is_valid = true" `
      -Actual      "probe reported is_valid = false" `
      -RepairHint  "check onLoad / onShow for unhandled exceptions"
    $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.9 -Force
    return $issue
  }

  # passed
  Write-Host "[automator-check] passed"
  $passed = [PSCustomObject]@{
    issue_id     = "passed|$PagePath|automator"
    status       = "passed"
    issue_type   = $null
    target       = $null
    expected     = "page healthy"
    actual       = "page healthy"
    severity     = "info"
    source       = "automator"
    page_path    = $PagePath
    project_path = $ProjectPath
    repair_hint  = ""
    retryable    = $false
    timestamp    = (Get-Date -Format "o")
  }
  $passed | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.95 -Force
  return $passed
}

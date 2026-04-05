. "$PSScriptRoot\New-PageIssue.ps1"

function Invoke-CompileHealthOverlay {
  param(
    [Parameter(Mandatory = $true)][string]$PagePath,
    [Parameter(Mandatory = $true)][string]$ProjectPath
  )

  $normalizedPagePath = $PagePath.TrimStart('/').Trim()
  if ([string]::IsNullOrWhiteSpace($normalizedPagePath)) {
    $issue = New-PageIssue `
      -IssueType "generation_gate_rejected" `
      -Source "overlay" `
      -PagePath $PagePath `
      -ProjectPath $ProjectPath `
      -Target "page_path" `
      -Expected "non-empty page path" `
      -Actual "empty page path" `
      -RepairHint "provide a valid page path like pages/store/home/index"
    $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.95 -Force
    return $issue
  }

  $wxmlPath = Join-Path $ProjectPath ($normalizedPagePath + ".wxml")
  $jsPath = Join-Path $ProjectPath ($normalizedPagePath + ".js")
  $jsonPath = Join-Path $ProjectPath ($normalizedPagePath + ".json")
  $wxssPath = Join-Path $ProjectPath ($normalizedPagePath + ".wxss")

  if (-not (Test-Path $wxmlPath)) {
    $passed = [pscustomobject]@{
      issue_id = "passed|$PagePath|overlay_compile"
      status = "passed"
      issue_type = $null
      target = $wxmlPath
      expected = "compile check skipped when page file is missing"
      actual = "target page wxml does not exist in this project context"
      severity = "info"
      source = "overlay"
      page_path = $PagePath
      project_path = $ProjectPath
      repair_hint = ""
      retryable = $false
      timestamp = (Get-Date -Format "o")
    }
    $passed | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.7 -Force
    return $passed
  }

  $files = @()
  foreach ($entry in @(
      @{ path = $wxmlPath; ext = ".wxml" },
      @{ path = $jsPath; ext = ".js" },
      @{ path = $jsonPath; ext = ".json" },
      @{ path = $wxssPath; ext = ".wxss" }
    )) {
    if (Test-Path $entry.path) {
      $content = Get-Content -Path $entry.path -Raw -Encoding UTF8
      $bundlePath = ($normalizedPagePath + $entry.ext).Replace('\', '/')
      $files += [pscustomobject]@{
        path = $bundlePath
        content = [string]$content
      }
    }
  }

  if ($files.Count -eq 0) {
    $issue = New-PageIssue `
      -IssueType "generation_gate_rejected" `
      -Source "overlay" `
      -PagePath $PagePath `
      -ProjectPath $ProjectPath `
      -Target $normalizedPagePath `
      -Expected "page files available for compile checks" `
      -Actual "no page files found" `
      -RepairHint "check page path and file generation output"
    $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.95 -Force
    return $issue
  }

  $wxmlContent = Get-Content -Path $wxmlPath -Raw -Encoding UTF8
  if ($wxmlContent -match '>[^<]*[^\x00-\x7F][^<]*\?</text>' -or
      $wxmlContent -match '\?/[a-zA-Z][\w-]*>' -or
      $wxmlContent -match '(?<!\{)\{[^{}\r\n]+\}\}') {
    $issue = New-PageIssue `
      -IssueType "text_encoding_garbled" `
      -Source "overlay" `
      -PagePath $PagePath `
      -ProjectPath $ProjectPath `
      -Target ($normalizedPagePath + ".wxml") `
      -Expected "readable UI text and valid template delimiters" `
      -Actual "suspected mojibake or malformed expression in WXML text nodes" `
      -RepairHint "normalize mojibake labels and malformed expression delimiters"
    $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.92 -Force
    return $issue
  }

  if ($wxmlContent -match '(?<!<)/[a-zA-Z][\w-]*\s*>') {
    $issue = New-PageIssue `
      -IssueType "generation_gate_rejected" `
      -Source "overlay" `
      -PagePath $PagePath `
      -ProjectPath $ProjectPath `
      -Target ($normalizedPagePath + ".wxml") `
      -Expected "well-formed WXML closing tags like </text>" `
      -Actual "malformed closing tag token detected (likely missing '<')" `
      -RepairHint "replace malformed '/tag>' with proper '</tag>' tokens"
    $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.95 -Force
    return $issue
  }

  $openMustache = [regex]::Matches($wxmlContent, '\{\{').Count
  $closeMustache = [regex]::Matches($wxmlContent, '\}\}').Count
  if ($openMustache -ne $closeMustache -or
      $wxmlContent -match '\{\{[^}]*`[^}]*\}\}' -or
      $wxmlContent -match '(?<!\{)\{[^{}\r\n]+\}(?!\})') {
    $issue = New-PageIssue `
      -IssueType "generation_gate_rejected" `
      -Source "overlay" `
      -PagePath $PagePath `
      -ProjectPath $ProjectPath `
      -Target ($normalizedPagePath + ".wxml") `
      -Expected "valid WXML template expressions" `
      -Actual "suspected malformed mustache expression in WXML" `
      -RepairHint "fix WXML expression syntax around {{ ... }} and remove unexpected backticks"
    $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.92 -Force
    return $issue
  }

  $repoRoot = Split-Path $PSScriptRoot -Parent
  $validatorScript = Join-Path $repoRoot "scripts\validators\validate-bundle-ast.mjs"
  $node = Get-Command node -ErrorAction SilentlyContinue
  if ((Test-Path $validatorScript) -and $null -ne $node) {
    $tempInput = Join-Path ([System.IO.Path]::GetTempPath()) ("compile-overlay-" + [guid]::NewGuid().ToString("N") + ".json")
    try {
      $bundle = [pscustomobject]@{
        page_name = ($normalizedPagePath -replace '^pages/', '')
        files = $files
      }
      $payload = $bundle | ConvertTo-Json -Depth 10
      [System.IO.File]::WriteAllText($tempInput, $payload, (New-Object System.Text.UTF8Encoding($false)))

      $rawOutput = & $node.Source $validatorScript --input $tempInput 2>$null
      if ($LASTEXITCODE -eq 0) {
        $parsed = $rawOutput | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($parsed -and $parsed.diagnostics) {
          $errors = @($parsed.diagnostics | Where-Object { $_.severity -eq 'error' })
          if ($errors.Count -gt 0) {
            $first = $errors[0]
            $fileRef = if ($first.file) { [string]$first.file } else { $normalizedPagePath }
            $issue = New-PageIssue `
              -IssueType "generation_gate_rejected" `
              -Source "overlay" `
              -PagePath $PagePath `
              -ProjectPath $ProjectPath `
              -Target $fileRef `
              -Expected "no compile-level diagnostics" `
              -Actual ("ast diagnostic: " + [string]$first.code + " - " + [string]$first.message) `
              -RepairHint "fix page template/script syntax and rerun compile checks"
            $issue | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.9 -Force
            return $issue
          }
        }
      }
    }
    catch {
      # Overlay must not break detector round on validator runtime exceptions.
    }
    finally {
      if (Test-Path $tempInput) {
        Remove-Item -Path $tempInput -Force -ErrorAction SilentlyContinue
      }
    }
  }

  $passed = [pscustomobject]@{
    issue_id = "passed|$PagePath|overlay_compile"
    status = "passed"
    issue_type = $null
    target = $null
    expected = "compile health clean"
    actual = "no compile-level issue detected"
    severity = "info"
    source = "overlay"
    page_path = $PagePath
    project_path = $ProjectPath
    repair_hint = ""
    retryable = $false
    timestamp = (Get-Date -Format "o")
  }
  $passed | Add-Member -NotePropertyName detector_confidence -NotePropertyValue 0.85 -Force
  return $passed
}

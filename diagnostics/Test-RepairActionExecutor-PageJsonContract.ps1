. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-page-json-contract-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'pages\about') -Force | Out-Null

try {
  # Case 1: usingComponents should be an object.
  '{ "usingComponents": "bad" }' | Set-Content -Path (Join-Path $root 'pages\about\index.json') -Encoding UTF8

  $issue1 = [pscustomobject]@{
    issue_type = 'generation_gate_rejected'
    page_path = 'pages/about/index'
    target = 'pages/about/index.json'
    actual = "JSON Error: usingComponents in 'pages/about/index.json' must be an object."
  }

  $result1 = Invoke-RepairActionExecutor -Issue $issue1 -ProjectPath $root
  if (-not $result1.applied -or $result1.reason -ne 'normalized_page_json_usingcomponents_object') {
    throw 'generation_gate_rejected should normalize usingComponents object'
  }

  $jsonText1 = Get-Content (Join-Path $root 'pages\about\index.json') -Raw -Encoding UTF8
  if ($jsonText1 -notmatch '"usingComponents"\s*:\s*\{\s*\}') {
    throw 'usingComponents should be normalized to an empty object'
  }

  # Case 2: invalid page config key should be removed.
  '{ "usingComponents": {}, "pages": ["pages/home/index"] }' | Set-Content -Path (Join-Path $root 'pages\about\index.json') -Encoding UTF8

  $issue2 = [pscustomobject]@{
    issue_type = 'generation_gate_rejected'
    page_path = 'pages/about/index'
    target = 'pages/about/index.json'
    actual = "JSON Error: Key 'pages' is not allowed in page config 'pages/about/index.json'."
  }

  $result2 = Invoke-RepairActionExecutor -Issue $issue2 -ProjectPath $root
  if (-not $result2.applied -or $result2.reason -ne 'removed_invalid_page_config_key') {
    throw 'generation_gate_rejected should remove invalid page config key'
  }

  $json2 = Get-Content (Join-Path $root 'pages\about\index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($json2.PSObject.Properties['pages']) {
    throw 'invalid page config key pages should be removed'
  }

  [pscustomobject]@{
    test = 'repair-action-executor-page-json-contract'
    pass = $true
    exit_code = 0
    repaired_issue_types = @('generation_gate_rejected')
  }
}
finally {
  if (Test-Path $root) {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}

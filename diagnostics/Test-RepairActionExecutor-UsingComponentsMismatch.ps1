. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-usingcomponents-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'pages\about') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'components\cta-button') -Force | Out-Null

Set-Content -Path (Join-Path $root 'pages\about\index.json') -Value '{ "usingComponents": { "cta-button": "/components/cta-button" } }' -Encoding UTF8
Set-Content -Path (Join-Path $root 'components\cta-button\index.js') -Value 'Component({ properties: {}, data: {}, methods: {} })' -Encoding UTF8

try {
  $issue = [pscustomobject]@{
    issue_type = 'generation_gate_rejected'
    page_path = 'pages/about/index'
    target = 'pages/about/index.json'
    actual = "JSON Error: usingComponents entry 'cta-button' in 'pages/about/index.json' must point to /components/<name>/index."
    repair_hint = 'fix usingComponents import path'
  }

  $result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
  if (-not $result.applied -or $result.reason -ne 'repaired_using_components_path') {
    throw 'generation_gate_rejected should repair usingComponents path mismatch'
  }

  $pageJson = Get-Content (Join-Path $root 'pages\about\index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$pageJson.usingComponents.'cta-button' -ne '/components/cta-button/index') {
    throw 'usingComponents path should be repaired to /components/cta-button/index'
  }

  [pscustomobject]@{
    test = 'repair-action-executor-usingcomponents-mismatch'
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

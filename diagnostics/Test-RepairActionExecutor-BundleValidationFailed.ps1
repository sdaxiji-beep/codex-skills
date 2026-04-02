. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-bundle-validation-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'pages\about') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'components\cta-button') -Force | Out-Null

try {
  Set-Content -Path (Join-Path $root 'components\cta-button\index.js') -Value 'Component({ properties: {}, data: {}, methods: {} })' -Encoding UTF8
  Set-Content -Path (Join-Path $root 'pages\about\index.json') -Value '{ "usingComponents": { "cta-button": "/components/cta-button" } }' -Encoding UTF8

  $issue1 = [pscustomobject]@{
    issue_type = 'bundle_validation_failed'
    page_path = 'pages/about/index'
    target = 'pages/about/index.json'
    actual = "JSON Error: usingComponents entry 'cta-button' in 'pages/about/index.json' must point to /components/<name>/index."
    repair_hint = 'fix usingComponents import path'
  }

  $result1 = Invoke-RepairActionExecutor -Issue $issue1 -ProjectPath $root
  if (-not $result1.applied -or $result1.reason -ne 'repaired_using_components_path') {
    throw 'bundle_validation_failed should repair usingComponents path mismatch'
  }

  $pageJson = Get-Content (Join-Path $root 'pages\about\index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$pageJson.usingComponents.'cta-button' -ne '/components/cta-button/index') {
    throw 'usingComponents path should be repaired to /components/cta-button/index'
  }

  @'
<view>
  <text>{{item.price`}}</text>
  <text>Broken?/text>
</view>
'@ | Set-Content -Path (Join-Path $root 'pages\about\index.wxml') -Encoding UTF8

  $issue2 = [pscustomobject]@{
    issue_type = 'bundle_validation_failed'
    page_path = 'pages/about/index'
    target = 'pages/about/index.wxml'
    actual = "bundle validation failed: unexpected token '.' in pages/about/index"
  }

  $result2 = Invoke-RepairActionExecutor -Issue $issue2 -ProjectPath $root
  if (-not $result2.applied -or $result2.reason -ne 'normalized_wxml_compile_blockers') {
    throw 'bundle_validation_failed should normalize WXML compile blockers'
  }

  $fixed = Get-Content (Join-Path $root 'pages\about\index.wxml') -Raw -Encoding UTF8
  if ($fixed -match '`' -or $fixed -match '\?/text>') {
    throw 'wxml compile blockers should be normalized for bundle_validation_failed'
  }

  [pscustomobject]@{
    test = 'repair-action-executor-bundle-validation-failed'
    pass = $true
    exit_code = 0
    repaired_issue_types = @('bundle_validation_failed')
  }
}
finally {
  if (Test-Path $root) {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}

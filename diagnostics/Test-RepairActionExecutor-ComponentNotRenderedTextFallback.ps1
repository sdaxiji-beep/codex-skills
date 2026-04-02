. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-component-not-rendered-text-fallback-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'pages\home') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'components\cta-button') -Force | Out-Null

Set-Content -Path (Join-Path $root 'pages\home\index.wxml') -Value '<view><cta-button /></view>' -Encoding UTF8
Set-Content -Path (Join-Path $root 'pages\home\index.json') -Value '{ "usingComponents": {} }' -Encoding UTF8
Set-Content -Path (Join-Path $root 'components\cta-button\index.js') -Value 'Component({ properties: {}, data: {}, methods: {} })' -Encoding UTF8

try {
  $issue = [pscustomobject]@{
    issue_type = 'component_not_rendered'
    page_path = 'pages/home/index'
    target = ''
    actual = "component 'cta-button' not rendered in pages/home/index"
  }

  $result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
  if (-not $result.applied -or $result.reason -ne 'registered_missing_component_dependency') {
    throw 'component_not_rendered text fallback should register component dependency'
  }

  $pageJson = Get-Content (Join-Path $root 'pages\home\index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$pageJson.usingComponents.'cta-button' -ne '/components/cta-button/index') {
    throw 'page json should register /components/cta-button/index from text fallback'
  }

  $second = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
  if ($second.status -ne 'blocked' -or $second.reason -ne 'component_dependency_already_registered') {
    throw 'second component_not_rendered attempt should block as already registered'
  }

  [pscustomobject]@{
    test = 'repair-action-executor-component-not-rendered-text-fallback'
    pass = $true
    exit_code = 0
    repaired_issue_types = @('component_not_rendered')
  }
}
finally {
  if (Test-Path $root) {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}

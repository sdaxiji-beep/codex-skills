. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-component-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'pages\home') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'components\cta-button') -Force | Out-Null

Set-Content -Path (Join-Path $root 'pages\home\index.wxml') -Value '<view><cta-button /></view>' -Encoding UTF8
Set-Content -Path (Join-Path $root 'pages\home\index.json') -Value '{ "usingComponents": {} }' -Encoding UTF8
Set-Content -Path (Join-Path $root 'components\cta-button\index.js') -Value 'Component({ properties: {}, data: {}, methods: {} })' -Encoding UTF8

try {
  $issue = [pscustomobject]@{
    issue_type = 'missing_required_element'
    target = 'cta-button'
    page_path = 'pages/home/index'
  }

  $result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
  if (-not $result.applied -or $result.reason -ne 'registered_missing_element_component_dependency') {
    throw 'missing_required_element component dependency repair should apply'
  }

  $pageJson = Get-Content (Join-Path $root 'pages\home\index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$pageJson.usingComponents.'cta-button' -ne '/components/cta-button/index') {
    throw 'page json should register /components/cta-button/index'
  }

  $alreadyRegistered = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
  if ($alreadyRegistered.status -ne 'blocked' -or $alreadyRegistered.reason -ne 'component_dependency_already_registered') {
    throw 'second registration attempt should block as already registered'
  }

  $componentRenderedIssue = [pscustomobject]@{
    issue_type = 'component_not_rendered'
    target = 'cta-button'
    page_path = 'pages/home/index'
  }
  $componentRenderedResult = Invoke-RepairActionExecutor -Issue $componentRenderedIssue -ProjectPath $root
  if ($componentRenderedResult.status -ne 'blocked' -or $componentRenderedResult.reason -ne 'component_dependency_already_registered') {
    throw 'component_not_rendered should reuse component dependency registration path'
  }

  [pscustomobject]@{
    test = 'repair-action-executor-component-registration'
    pass = $true
    exit_code = 0
    repaired_issue_types = @('missing_required_element', 'component_not_rendered')
  }
}
finally {
  if (Test-Path $root) {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}

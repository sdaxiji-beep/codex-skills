. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-route-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'pages\home') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'pages\about') -Force | Out-Null
Set-Content -Path (Join-Path $root 'pages\home\index.wxml') -Value '<view>home</view>' -Encoding UTF8
Set-Content -Path (Join-Path $root 'pages\about\index.wxml') -Value '<view>about</view>' -Encoding UTF8

$app = [pscustomobject]@{
  pages = @('pages/home/index')
  tabBar = [pscustomobject]@{
    list = @(
      [pscustomobject]@{ pagePath = 'pages/home/index'; text = 'Home' }
    )
  }
}
$app | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $root 'app.json') -Encoding UTF8

$wrongPathIssue = [pscustomobject]@{
  issue_type = 'wrong_page_path'
  expected = 'pages/about/index'
  page_path = 'pages/about/index'
}
$r1 = Invoke-RepairActionExecutor -Issue $wrongPathIssue -ProjectPath $root
if (-not $r1.applied -or $r1.reason -ne 'registered_and_prioritized_expected_page') {
  throw 'wrong_page_path repair should apply and prioritize expected page'
}
$appAfterWrongPath = Get-Content (Join-Path $root 'app.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($appAfterWrongPath.pages)[0] -ne 'pages/about/index') {
  throw 'wrong_page_path repair should move expected page to front'
}

$missingEntryIssue = [pscustomobject]@{
  issue_type = 'missing_page_entry'
  target = 'pages/about/index'
  page_path = 'pages/about/index'
}
$r2 = Invoke-RepairActionExecutor -Issue $missingEntryIssue -ProjectPath $root
if (-not $r2.applied -or $r2.reason -ne 'registered_missing_page_entry') {
  throw 'missing_page_entry repair should apply'
}
$appAfterEntry = Get-Content (Join-Path $root 'app.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($appAfterEntry.pages) -notcontains 'pages/about/index') {
  throw 'missing_page_entry repair should register page'
}

$tabIssue = [pscustomobject]@{
  issue_type = 'tabbar_item_missing'
  target = 'pages/about/index'
  page_path = 'pages/about/index'
}
$r3 = Invoke-RepairActionExecutor -Issue $tabIssue -ProjectPath $root
if (-not $r3.applied -or $r3.reason -ne 'registered_tabbar_item') {
  throw 'tabbar_item_missing repair should apply'
}
$appAfterTab = Get-Content (Join-Path $root 'app.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$tabPaths = @($appAfterTab.tabBar.list | ForEach-Object { [string]$_.pagePath })
if ($tabPaths -notcontains 'pages/about/index') {
  throw 'tabbar_item_missing repair should add tab entry'
}

Remove-Item -LiteralPath $root -Recurse -Force

[pscustomobject]@{
  test = 'repair-action-executor-route-fixes'
  pass = $true
  exit_code = 0
  repaired_issue_types = @('wrong_page_path', 'missing_page_entry', 'tabbar_item_missing')
}

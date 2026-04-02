. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-route-runtime-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'pages\cart') -Force | Out-Null

@'
<view>
  <text>{{item.price`}}</text>
</view>
'@ | Set-Content -Path (Join-Path $root 'pages\cart\index.wxml') -Encoding UTF8

try {
  $issue = [pscustomobject]@{
    issue_type = 'error_page_visible'
    page_path = 'pages/cart/index'
    actual = 'render layer reports __route__ is not defined'
  }

  $result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
  if (-not $result.applied -or $result.reason -ne 'normalized_route_runtime_blocker') {
    throw 'error_page_visible should normalize route runtime blocker when WXML is fixable'
  }

  $fixed = Get-Content (Join-Path $root 'pages\cart\index.wxml') -Raw -Encoding UTF8
  if ($fixed -match '`') {
    throw 'route runtime blocker normalization should remove backticks from WXML mustache'
  }
  if ($fixed -notmatch '\{\{item\.price\}\}') {
    throw 'route runtime blocker normalization should keep compile-safe mustache'
  }

  [pscustomobject]@{
    test = 'repair-action-executor-route-runtime-blocker'
    pass = $true
    exit_code = 0
    repaired_issue_types = @('error_page_visible')
  }
}
finally {
  if (Test-Path $root) {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}

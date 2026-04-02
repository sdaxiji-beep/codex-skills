. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-wxml-compile-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'pages\cart') -Force | Out-Null

@'
<view>
  <text>{{item.price`}}</text>
  <text class="muted">{{(item.price*item.qty).toFixed(2)}}</text>
  <text>Broken?/text>
</view>
'@ | Set-Content -Path (Join-Path $root 'pages\cart\index.wxml') -Encoding UTF8

try {
  $issue = [pscustomobject]@{
    issue_type = 'generation_gate_rejected'
    page_path = 'pages/cart/index'
    target = 'pages/cart/index.wxml'
    actual = "console compile error: unexpected token '.' in pages/cart/index"
  }

  $result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
  if (-not $result.applied -or $result.reason -ne 'normalized_wxml_compile_blockers') {
    throw 'generation_gate_rejected should normalize WXML compile blockers'
  }

  $fixed = Get-Content (Join-Path $root 'pages\cart\index.wxml') -Raw -Encoding UTF8
  if ($fixed -match '`') {
    throw 'backtick should be removed from mustache expression'
  }
  if ($fixed -match '\.toFixed\(') {
    throw 'toFixed should be removed from WXML expression'
  }
  if ($fixed -match '\?/text>') {
    throw 'malformed closing tag should be normalized'
  }
  if ($fixed -notmatch '\{\{item\.price\}\}') {
    throw 'simple mustache should remain after normalization'
  }
  if ($fixed -notmatch '\{\{\(item\.price\*item\.qty\)\}\}') {
    throw 'toFixed expression should degrade to compile-safe mustache'
  }

  [pscustomobject]@{
    test = 'repair-action-executor-wxml-compile-blockers'
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

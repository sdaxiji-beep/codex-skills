. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-required-text-fallback-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'pages\cart') -Force | Out-Null

@'
<view>
  <text class="title"></text>
  <text class="muted">Keep me</text>
</view>
'@ | Set-Content -Path (Join-Path $root 'pages\cart\index.wxml') -Encoding UTF8

try {
  $issue = [pscustomobject]@{
    issue_type = 'required_text_missing'
    page_path = 'pages/cart/index'
    expected = 'Cart'
    actual = "required text 'title' missing"
  }

  $result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
  if (-not $result.applied -or $result.reason -ne 'updated_required_text_node') {
    throw 'required_text_missing should update the targeted WXML text node from text evidence'
  }

  $fixed = Get-Content (Join-Path $root 'pages\cart\index.wxml') -Raw -Encoding UTF8
  if ($fixed -notmatch '<text class="title">Cart</text>') {
    throw 'fallback text evidence should update the title node to Cart'
  }
  if ($fixed -notmatch '<text class="muted">Keep me</text>') {
    throw 'unrelated text node should remain unchanged'
  }

  [pscustomobject]@{
    test = 'repair-action-executor-required-text-missing-text-fallback'
    pass = $true
    exit_code = 0
    repaired_issue_types = @('required_text_missing')
  }
}
finally {
  if (Test-Path $root) {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}

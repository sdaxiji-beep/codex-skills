. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-empty-list-text-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'pages\list') -Force | Out-Null

@'
<view class="page">
  <view class="empty-state">
    <text class="empty-hint">Old placeholder</text>
  </view>
</view>
'@ | Set-Content -Path (Join-Path $root 'pages\list\index.wxml') -Encoding UTF8

try {
  $issue = [pscustomobject]@{
    issue_type = 'empty_list_render'
    page_path = 'pages/list/index'
    target = $null
    expected = 'No items yet'
    actual = "missing empty state text 'empty-hint'"
    repair_hint = "empty-state class 'empty-hint' missing"
  }

  $result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
  if (-not $result.applied -or $result.reason -ne 'updated_empty_state_text_node') {
    throw 'empty_list_render text fallback should update the targeted empty-state text node'
  }

  $fixed = Get-Content (Join-Path $root 'pages\list\index.wxml') -Raw -Encoding UTF8
  if ($fixed -notmatch '<text class="empty-hint">No items yet</text>') {
    throw 'empty-state text fallback should update the targeted node to No items yet'
  }

  [pscustomobject]@{
    test = 'repair-action-executor-empty-list-render-text-fallback'
    pass = $true
    exit_code = 0
    repaired_issue_types = @('empty_list_render')
  }
}
finally {
  if (Test-Path $root) {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}

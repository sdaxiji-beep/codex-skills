. "$PSScriptRoot\\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-empty-list-short-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $root 'pages\catalog') -Force | Out-Null

$wxmlPath = Join-Path $root 'pages\catalog\index.wxml'
@'
<view class="page">
  <view class="empty-state">
    <text class="hint">Nothing here</text>
  </view>
</view>
'@ | Set-Content -Path $wxmlPath -Encoding UTF8

$issue = [pscustomobject]@{
  issue_type = 'empty_list_render'
  page_path  = 'pages/catalog/index'
  target     = 'empty-state.hint'
  expected   = 'No items yet'
}

$result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
if (-not $result.applied) {
  throw 'empty_list_render short target repair should apply'
}

$updated = Get-Content -Path $wxmlPath -Raw -Encoding UTF8
if ($updated -notmatch 'No items yet') {
  throw 'empty_list_render short target should update the matching empty-state text node'
}

[pscustomobject]@{
  test = 'repair-action-executor-empty-list-short-target'
  pass = $true
  exit_code = 0
  repaired_issue_types = @('empty_list_render')
}

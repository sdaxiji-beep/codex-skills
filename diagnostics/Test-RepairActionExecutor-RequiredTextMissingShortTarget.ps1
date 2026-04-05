. "$PSScriptRoot\\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-required-text-short-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path (Join-Path $root 'pages\home') -Force | Out-Null

$wxmlPath = Join-Path $root 'pages\home\index.wxml'
@'
<view class="page">
  <text class="title">Old Title</text>
</view>
'@ | Set-Content -Path $wxmlPath -Encoding UTF8

$issue = [pscustomobject]@{
  issue_type = 'required_text_missing'
  page_path  = 'pages/home/index'
  target     = 'text.title'
  expected   = 'Home Title'
}

$result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
if (-not $result.applied) {
  throw 'required_text_missing short target repair should apply'
}

$updated = Get-Content -Path $wxmlPath -Raw -Encoding UTF8
if ($updated -notmatch 'Home Title') {
  throw 'required_text_missing short target should update the matching text node'
}

[pscustomobject]@{
  test = 'repair-action-executor-required-text-short-target'
  pass = $true
  exit_code = 0
  repaired_issue_types = @('required_text_missing')
}

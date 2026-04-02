. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-data-not-bound-text-fallback-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $root -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root 'pages\home') -Force | Out-Null

@"
Page({
  data: {
  },
  onLoad() {}
})
"@ | Set-Content -Path (Join-Path $root 'pages\home\index.js') -Encoding UTF8

try {
  $issue = [pscustomobject]@{
    issue_type = 'data_not_bound'
    page_path = 'pages/home/index'
    target = ''
    actual = "data key 'products' not bound in pages/home/index"
  }

  $result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
  if (-not $result.applied -or $result.reason -ne 'added_missing_page_data_key') {
    throw 'data_not_bound text fallback should add missing page data key'
  }

  $updated = Get-Content (Join-Path $root 'pages\home\index.js') -Raw -Encoding UTF8
  if ($updated -notmatch 'products\s*:\s*null') {
    throw 'page data object should contain products: null from text fallback'
  }

  $second = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
  if ($second.status -ne 'blocked' -or $second.reason -ne 'data_key_already_present') {
    throw 'second data_not_bound text fallback attempt should block as already present'
  }

  [pscustomobject]@{
    test = 'repair-action-executor-data-not-bound-text-fallback'
    pass = $true
    exit_code = 0
    repaired_issue_types = @('data_not_bound')
  }
}
finally {
  if (Test-Path $root) {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
  }
}

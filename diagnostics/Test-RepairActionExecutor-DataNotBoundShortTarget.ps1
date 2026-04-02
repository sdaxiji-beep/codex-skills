. "$PSScriptRoot\\Invoke-RepairActionExecutor.ps1"

$root = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-data-short-" + [guid]::NewGuid().ToString("N"))
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
    target = 'data.products'
    page_path = 'pages/home/index'
  }

  $result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
  if (-not $result.applied -or $result.reason -ne 'added_missing_page_data_key') {
    throw 'data_not_bound short target should add missing page data key'
  }

  $updated = Get-Content (Join-Path $root 'pages\home\index.js') -Raw -Encoding UTF8
  if ($updated -notmatch 'products\s*:\s*null') {
    throw 'page data object should contain products: null from short target'
  }

  [pscustomobject]@{
    test = 'repair-action-executor-data-not-bound-short-target'
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

. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

function Assert-Equal {
  param($Actual, $Expected, [string]$Message)
  if ($Actual -ne $Expected) {
    throw "assert failed: $Message (actual=$Actual expected=$Expected)"
  }
}

Write-Host "[test] Start RepairActionExecutor WXML encoding check..." -ForegroundColor Cyan

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("repair-wxml-" + [System.Guid]::NewGuid().ToString("N"))
$pageDir = Join-Path $tmp "pages\cart"
New-Item -ItemType Directory -Path $pageDir -Force | Out-Null

@'
<view>
  <text class="title">Moji?/text>
  <text class="muted">Bad{(item.price*item.qty).toFixed(2)}}</text>
  <button bindtap="checkout">BadBtn?</button>
</view>
'@ | Set-Content -Path (Join-Path $pageDir "index.wxml") -Encoding UTF8

try {
  $issue = [PSCustomObject]@{
    issue_type = "text_encoding_garbled"
    target = "pages/cart/index.wxml"
  }

  $r = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $tmp
  Assert-Equal $r.status "applied" "wxml encoding repair should be applied"

  $fixed = Get-Content (Join-Path $pageDir "index.wxml") -Raw -Encoding UTF8
  if ($fixed -match '\?/text>') {
    throw "assert failed: malformed closing token should be fixed"
  }
  if ($fixed -match '(?<!\{)\{([^\r\n{}]+)\}\}') {
    throw "assert failed: single-open double-close template token should be normalized"
  }
  if ($fixed -notmatch '<text class="title">Cart</text>') {
    throw "assert failed: title should be normalized to Cart"
  }
  if ($fixed -notmatch '<button bindtap="checkout">Checkout</button>') {
    throw "assert failed: button label should be normalized to Checkout"
  }

  Write-Host "[test] PASS: RepairActionExecutor fixed WXML encoding" -ForegroundColor Green
  exit 0
}
finally {
  if (Test-Path $tmp) {
    Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

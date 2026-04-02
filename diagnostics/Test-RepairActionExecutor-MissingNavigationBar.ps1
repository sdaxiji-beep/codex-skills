. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path $env:TEMP ("repair-nav-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $root "pages\orders") -Force | Out-Null

Set-Content -Path (Join-Path $root "pages\orders\index.wxml") -Value "<view>orders</view>" -Encoding UTF8
Set-Content -Path (Join-Path $root "pages\orders\index.json") -Value "{`n  `"usingComponents`": {}`n}" -Encoding UTF8

$issue = [pscustomobject]@{
    issue_type = "missing_navigation_bar"
    page_path = "pages/orders/index"
    target = $null
}

$result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
$json = Get-Content -Path (Join-Path $root "pages\orders\index.json") -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop

$pass = (
    $result.status -eq "applied" -and
    $result.reason -eq "added_navigation_bar_title" -and
    [string]$json.navigationBarTitleText -eq "Orders"
)

$summary = [pscustomobject]@{
    test = "repair-action-executor-missing-navigation-bar"
    pass = $pass
    exit_code = $(if ($pass) { 0 } else { 1 })
    result = $result
}

$summary | ConvertTo-Json -Depth 6
exit $summary.exit_code

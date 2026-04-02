. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path $env:TEMP ("repair-button-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $root "pages\checkout") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root "components\cta-button") -Force | Out-Null

Set-Content -Path (Join-Path $root "pages\checkout\index.json") -Value "{`n  `"usingComponents`": {}`n}" -Encoding UTF8
Set-Content -Path (Join-Path $root "pages\checkout\index.wxml") -Value "<view><cta-button /></view>" -Encoding UTF8
Set-Content -Path (Join-Path $root "components\cta-button\index.js") -Value "Component({ properties: {}, methods: {} })" -Encoding UTF8

$issue = [pscustomobject]@{
    issue_type = "missing_required_button"
    page_path = "pages/checkout/index"
    target = "cta-button"
}

$result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
$json = Get-Content -Path (Join-Path $root "pages\checkout\index.json") -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$registered = $json.usingComponents.PSObject.Properties['cta-button']

$pass = (
    $result.status -eq "applied" -and
    $result.reason -eq "registered_missing_button_component_dependency" -and
    $null -ne $registered -and
    [string]$registered.Value -eq "/components/cta-button/index"
)

$summary = [pscustomobject]@{
    test = "repair-action-executor-missing-required-button"
    pass = $pass
    exit_code = $(if ($pass) { 0 } else { 1 })
    result = $result
}

$summary | ConvertTo-Json -Depth 6
exit $summary.exit_code

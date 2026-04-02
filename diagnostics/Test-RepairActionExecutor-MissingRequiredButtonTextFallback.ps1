. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path $env:TEMP ("repair-button-text-fallback-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $root "pages\checkout") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root "components\cta-button") -Force | Out-Null

Set-Content -Path (Join-Path $root "pages\checkout\index.json") -Value "{`n  `"usingComponents`": {}`n}" -Encoding UTF8
Set-Content -Path (Join-Path $root "pages\checkout\index.wxml") -Value "<view><cta-button /></view>" -Encoding UTF8
Set-Content -Path (Join-Path $root "components\cta-button\index.js") -Value "Component({ properties: {}, methods: {} })" -Encoding UTF8

try {
    $issue = [pscustomobject]@{
        issue_type = 'missing_required_button'
        page_path = 'pages/checkout/index'
        target = ''
        actual = "button 'cta-button' missing on pages/checkout/index"
    }

    $result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
    if (-not $result.applied -or $result.reason -ne 'registered_missing_button_component_dependency') {
        throw 'missing_required_button text fallback should register component dependency'
    }

    $pageJson = Get-Content (Join-Path $root 'pages\checkout\index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$pageJson.usingComponents.'cta-button' -ne '/components/cta-button/index') {
        throw 'page json should register /components/cta-button/index from text fallback'
    }

    $second = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
    if ($second.status -ne 'blocked' -or $second.reason -ne 'component_dependency_already_registered') {
        throw 'second missing_required_button attempt should block as already registered'
    }

    [pscustomobject]@{
        test = 'repair-action-executor-missing-required-button-text-fallback'
        pass = $true
        exit_code = 0
        repaired_issue_types = @('missing_required_button')
    }
}
finally {
    if (Test-Path $root) {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

. "$PSScriptRoot\Invoke-RepairActionExecutor.ps1"

$root = Join-Path $env:TEMP ("repair-element-text-fallback-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path (Join-Path $root "pages\catalog") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $root "components\product-card") -Force | Out-Null

Set-Content -Path (Join-Path $root "pages\catalog\index.json") -Value "{`n  `"usingComponents`": {}`n}" -Encoding UTF8
Set-Content -Path (Join-Path $root "pages\catalog\index.wxml") -Value "<view><product-card /></view>" -Encoding UTF8
Set-Content -Path (Join-Path $root "components\product-card\index.js") -Value "Component({ properties: {}, methods: {} })" -Encoding UTF8

try {
    $issue = [pscustomobject]@{
        issue_type = 'missing_required_element'
        page_path = 'pages/catalog/index'
        target = ''
        actual = "element 'product-card' missing on pages/catalog/index"
    }

    $result = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
    if (-not $result.applied -or $result.reason -ne 'registered_missing_element_component_dependency') {
        throw 'missing_required_element text fallback should register component dependency'
    }

    $pageJson = Get-Content (Join-Path $root 'pages\catalog\index.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$pageJson.usingComponents.'product-card' -ne '/components/product-card/index') {
        throw 'page json should register /components/product-card/index from text fallback'
    }

    $second = Invoke-RepairActionExecutor -Issue $issue -ProjectPath $root
    if ($second.status -ne 'blocked' -or $second.reason -ne 'component_dependency_already_registered') {
        throw 'second missing_required_element attempt should block as already registered'
    }

    [pscustomobject]@{
        test = 'repair-action-executor-missing-required-element-text-fallback'
        pass = $true
        exit_code = 0
        repaired_issue_types = @('missing_required_element')
    }
}
finally {
    if (Test-Path $root) {
        Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

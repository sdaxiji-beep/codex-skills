param()

$ErrorActionPreference = 'Stop'

function Invoke-CiTest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action
    )

    try {
        & $Action
        return [pscustomobject]@{
            name = $Name
            pass = $true
        }
    }
    catch {
        return [pscustomobject]@{
            name = $Name
            pass = $false
            error = $_.Exception.Message
        }
    }
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$results = @()

$results += Invoke-CiTest -Name 'guard-check' -Action {
    $guard = (& (Join-Path $PSScriptRoot 'test-wechat-skill.ps1') -GuardCheckOnly) | ConvertFrom-Json
    if (-not $guard.pass) {
        throw 'guard-check failed'
    }
}

$results += Invoke-CiTest -Name 'boundary-doc-sync' -Action {
    $result = & (Join-Path $PSScriptRoot 'test-wechat-mcp-tool-boundary-doc-sync.ps1')
    if (-not $result.pass) {
        throw 'boundary-doc-sync failed'
    }
}

$results += Invoke-CiTest -Name 'external-entrypoints-doc' -Action {
    $result = & (Join-Path $PSScriptRoot 'test-external-client-entrypoints-doc.ps1')
    if (-not $result.pass) {
        throw 'external-entrypoints-doc failed'
    }
}

$results += Invoke-CiTest -Name 'external-payload-doc' -Action {
    $result = & (Join-Path $PSScriptRoot 'test-external-client-payload-contract-doc.ps1')
    if (-not $result.pass) {
        throw 'external-payload-doc failed'
    }
}

$passed = @($results | Where-Object { $_.pass }).Count
$failed = @($results | Where-Object { -not $_.pass }).Count
$summary = [pscustomobject]@{
    test = 'ci-minimal'
    pass = ($failed -eq 0)
    total = $results.Count
    passed = $passed
    failed = $failed
    results = $results
}

$summary | ConvertTo-Json -Depth 6

if ($failed -gt 0) {
    exit 1
}

exit 0

param()

$ErrorActionPreference = 'Stop'

function Invoke-AcceptanceTest {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    $started = Get-Date
    try {
        $output = & $ScriptPath 2>&1
        $durationMs = [math]::Round(((Get-Date) - $started).TotalMilliseconds, 2)
        return [pscustomobject]@{
            name = $Name
            pass = $true
            duration_ms = $durationMs
            script = $ScriptPath
            output = @($output)
        }
    }
    catch {
        $durationMs = [math]::Round(((Get-Date) - $started).TotalMilliseconds, 2)
        return [pscustomobject]@{
            name = $Name
            pass = $false
            duration_ms = $durationMs
            script = $ScriptPath
            error = $_.Exception.Message
        }
    }
}

$repoRoot = Split-Path $PSScriptRoot -Parent

$tests = @(
    @{ name = 'mcp-server-smoke'; script = (Join-Path $PSScriptRoot 'test-wechat-mcp-server-smoke.ps1') }
    @{ name = 'mcp-server-inventory'; script = (Join-Path $PSScriptRoot 'test-wechat-mcp-server-inventory.ps1') }
    @{ name = 'mcp-distribution-metadata'; script = (Join-Path $PSScriptRoot 'test-wechat-mcp-distribution-metadata.ps1') }
    @{ name = 'mcp-distribution-quickstart'; script = (Join-Path $PSScriptRoot 'test-wechat-mcp-distribution-quickstart.ps1') }
    @{ name = 'mcp-installer-readiness'; script = (Join-Path $PSScriptRoot 'test-wechat-mcp-installer-readiness.ps1') }
    @{ name = 'mcp-registration-guidance'; script = (Join-Path $PSScriptRoot 'test-wechat-mcp-registration-guidance.ps1') }
    @{ name = 'mcp-registry-readiness'; script = (Join-Path $PSScriptRoot 'test-wechat-mcp-registry-readiness.ps1') }
)

$results = @()
foreach ($test in $tests) {
    $results += Invoke-AcceptanceTest -Name $test.name -ScriptPath $test.script
}

$passed = @($results | Where-Object { $_.pass }).Count
$failed = @($results | Where-Object { -not $_.pass }).Count
$totalDurationMs = [math]::Round((@($results | Measure-Object -Property duration_ms -Sum).Sum), 2)

$summary = [pscustomobject]@{
    test = 'wechat-mcp-distribution-acceptance'
    pass = ($failed -eq 0)
    total = $results.Count
    passed = $passed
    failed = $failed
    total_duration_ms = $totalDurationMs
    results = $results
}

$summary | ConvertTo-Json -Depth 8

if ($failed -gt 0) {
    exit 1
}

exit 0

[CmdletBinding()]
param(
    [switch]$AsJson
)

$repoRoot = Split-Path $PSScriptRoot -Parent
$statusScript = Join-Path $PSScriptRoot 'mcp-write-gate-status.ps1'
$dryRunScript = Join-Path $PSScriptRoot 'mcp-write-gate-dryrun.ps1'
$policyPath = Join-Path $repoRoot 'mcp\wechat-devtools-mcp-write\policy.json'

if (-not (Test-Path $statusScript)) {
    throw "Gate status script not found: $statusScript"
}
if (-not (Test-Path $dryRunScript)) {
    throw "Gate dry-run script not found: $dryRunScript"
}
if (-not (Test-Path $policyPath)) {
    throw "Policy not found: $policyPath"
}

$status = (powershell -ExecutionPolicy Bypass -File $statusScript -AsJson) | ConvertFrom-Json
$dryRun = (powershell -ExecutionPolicy Bypass -File $dryRunScript -AsJson) | ConvertFrom-Json
$policy = Get-Content $policyPath -Raw | ConvertFrom-Json

$readyChecks = [ordered]@{
    policy_enabled = [bool]$status.gates.policy_enabled
    review_gate_open = [bool]$status.gates.review_gate_open
    service_env_ok = [bool]$status.gates.service_env.ok
    tool_env_ok = [bool]$status.gates.preview_tool_env.ok
    dryrun_not_fully_blocked = (-not [bool]$dryRun.all_blocked)
}

$failedChecks = @()
foreach ($pair in $readyChecks.GetEnumerator()) {
    if (-not $pair.Value) {
        $failedChecks += $pair.Key
    }
}

$result = [ordered]@{
    server = 'wechat-devtools-mcp-write'
    timestamp = (Get-Date).ToString('o')
    can_enable = ($failedChecks.Count -eq 0)
    failed_checks = @($failedChecks)
    blocked_by = @($status.blocked_by)
    current = [ordered]@{
        policy_enabled = [bool]$status.gates.policy_enabled
        review_gate_open = [bool]$status.gates.review_gate_open
        service_env = [ordered]@{
            name = [string]$status.gates.service_env.name
            required = [string]$status.gates.service_env.required
            actual = [string]$status.gates.service_env.actual
            ok = [bool]$status.gates.service_env.ok
        }
        preview_tool_env = [ordered]@{
            name = [string]$status.gates.preview_tool_env.name
            required = [string]$status.gates.preview_tool_env.required
            actual = [string]$status.gates.preview_tool_env.actual
            ok = [bool]$status.gates.preview_tool_env.ok
        }
    }
    dryrun = [ordered]@{
        all_blocked = [bool]$dryRun.all_blocked
        matrix = @($dryRun.matrix)
    }
    proposed_first_tool = if ($policy.proposed_tools -and $policy.proposed_tools.Count -gt 0) {
        [string]$policy.proposed_tools[0].name
    } else {
        ''
    }
}

$artifactPath = Join-Path $repoRoot 'artifacts\mcp-write-readiness-latest.json'
New-Item -ItemType Directory -Force -Path (Split-Path $artifactPath) | Out-Null
$result | ConvertTo-Json -Depth 10 | Set-Content -Path $artifactPath -Encoding UTF8

if ($AsJson) {
    $result | ConvertTo-Json -Depth 10
}
else {
    Write-Host "server: $($result.server)"
    Write-Host "can_enable: $($result.can_enable)"
    if ($result.failed_checks.Count -gt 0) {
        Write-Host "failed_checks: $($result.failed_checks -join ', ')"
    }
    if ($result.blocked_by.Count -gt 0) {
        Write-Host "blocked_by: $($result.blocked_by -join '; ')"
    }
    Write-Host "proposed_first_tool: $($result.proposed_first_tool)"
    Write-Host "artifact: $artifactPath"
}

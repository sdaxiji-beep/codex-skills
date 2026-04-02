[CmdletBinding()]
param(
    [switch]$AsJson
)

$repoRoot = Split-Path $PSScriptRoot -Parent
$policyPath = Join-Path $repoRoot 'mcp\wechat-devtools-mcp-write\policy.json'
$artifactPath = Join-Path $repoRoot 'artifacts\mcp-write-enable-simulation-latest.json'

if (-not (Test-Path $policyPath)) {
    throw "Policy not found: $policyPath"
}

$policy = Get-Content $policyPath -Raw | ConvertFrom-Json

function New-ReadinessResult {
    param(
        [bool]$PolicyEnabled,
        [bool]$ReviewGateOpen,
        [bool]$ServiceEnvOk,
        [bool]$ToolEnvOk
    )

    $failed = @()
    if (-not $PolicyEnabled) { $failed += 'policy_enabled' }
    if (-not $ReviewGateOpen) { $failed += 'review_gate_open' }
    if (-not $ServiceEnvOk) { $failed += 'service_env_ok' }
    if (-not $ToolEnvOk) { $failed += 'tool_env_ok' }
    return [ordered]@{
        can_enable = ($failed.Count -eq 0)
        failed_checks = @($failed)
    }
}

$serviceEnvName = if ($policy.activation.env) { [string]$policy.activation.env } else { 'WECHAT_WRITE_MCP_ENABLE' }
$serviceEnvRequired = if ($policy.activation.required_value) { [string]$policy.activation.required_value } else { '1' }
$previewTool = @($policy.proposed_tools | Where-Object { $_.name -eq 'preview_project' })[0]
$toolEnvName = if ($previewTool -and $previewTool.release_gate.tool_flag) { [string]$previewTool.release_gate.tool_flag } else { 'WECHAT_WRITE_TOOL_PREVIEW_ENABLE' }
$toolEnvRequired = if ($previewTool -and $previewTool.release_gate.required_value) { [string]$previewTool.release_gate.required_value } else { '1' }

$current = New-ReadinessResult `
    -PolicyEnabled ([bool]($policy.enabled -eq $true)) `
    -ReviewGateOpen ([bool]($policy.guardrails.allow_tools_before_policy_review -eq $true)) `
    -ServiceEnvOk ([string][Environment]::GetEnvironmentVariable($serviceEnvName) -eq $serviceEnvRequired) `
    -ToolEnvOk ([string][Environment]::GetEnvironmentVariable($toolEnvName) -eq $toolEnvRequired)

$simulatedPolicyEnabled = $true
$simulatedReviewOpen = $true

$simNoEnv = New-ReadinessResult `
    -PolicyEnabled $simulatedPolicyEnabled `
    -ReviewGateOpen $simulatedReviewOpen `
    -ServiceEnvOk $false `
    -ToolEnvOk $false

$simWithEnv = New-ReadinessResult `
    -PolicyEnabled $simulatedPolicyEnabled `
    -ReviewGateOpen $simulatedReviewOpen `
    -ServiceEnvOk $true `
    -ToolEnvOk $true

$result = [ordered]@{
    server = 'wechat-devtools-mcp-write'
    timestamp = (Get-Date).ToString('o')
    policy_path = $policyPath
    current = $current
    simulation = [ordered]@{
        policy_changes = [ordered]@{
            enabled = $simulatedPolicyEnabled
            allow_tools_before_policy_review = $simulatedReviewOpen
        }
        no_env = $simNoEnv
        with_env = $simWithEnv
        required_env = [ordered]@{
            service = [ordered]@{
                name = $serviceEnvName
                required = $serviceEnvRequired
            }
            preview_tool = [ordered]@{
                name = $toolEnvName
                required = $toolEnvRequired
            }
        }
    }
    notes = @(
        'This is a dry-run simulation only.',
        'policy.json was not modified.'
    )
}

New-Item -ItemType Directory -Force -Path (Split-Path $artifactPath) | Out-Null
$result | ConvertTo-Json -Depth 8 | Set-Content -Path $artifactPath -Encoding UTF8

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    Write-Host "server: $($result.server)"
    Write-Host "current.can_enable: $($result.current.can_enable)"
    Write-Host "sim.no_env.can_enable: $($result.simulation.no_env.can_enable)"
    Write-Host "sim.with_env.can_enable: $($result.simulation.with_env.can_enable)"
    Write-Host "artifact: $artifactPath"
}

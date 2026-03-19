[CmdletBinding()]
param(
    [switch]$AsJson
)

$repoRoot = Split-Path $PSScriptRoot -Parent
$policyPath = Join-Path $repoRoot 'mcp\wechat-devtools-mcp-write\policy.json'

if (-not (Test-Path $policyPath)) {
    throw "Policy file not found: $policyPath"
}

$policy = Get-Content $policyPath -Raw | ConvertFrom-Json

$serviceEnvName = if ($policy.activation.env) { [string]$policy.activation.env } else { 'WECHAT_WRITE_MCP_ENABLE' }
$serviceEnvRequired = if ($policy.activation.required_value) { [string]$policy.activation.required_value } else { '1' }
$serviceEnvActual = [string][Environment]::GetEnvironmentVariable($serviceEnvName)

$previewTool = $null
if ($policy.proposed_tools) {
    $previewTool = @($policy.proposed_tools | Where-Object { $_.name -eq 'preview_project' })[0]
}
$toolEnvName = if ($previewTool -and $previewTool.release_gate.tool_flag) { [string]$previewTool.release_gate.tool_flag } else { 'WECHAT_WRITE_TOOL_PREVIEW_ENABLE' }
$toolEnvRequired = if ($previewTool -and $previewTool.release_gate.required_value) { [string]$previewTool.release_gate.required_value } else { '1' }
$toolEnvActual = [string][Environment]::GetEnvironmentVariable($toolEnvName)

$serviceEnabled = ($policy.enabled -eq $true)
$reviewGateEnabled = ($policy.guardrails.allow_tools_before_policy_review -eq $true)
$serviceEnvOk = ($serviceEnvActual -eq $serviceEnvRequired)
$toolEnvOk = ($toolEnvActual -eq $toolEnvRequired)

$blocks = @()
if (-not $serviceEnabled) { $blocks += 'policy.enabled=false' }
if (-not $reviewGateEnabled) { $blocks += 'allow_tools_before_policy_review=false' }
if (-not $serviceEnvOk) { $blocks += "$serviceEnvName!=$serviceEnvRequired" }
if (-not $toolEnvOk) { $blocks += "$toolEnvName!=$toolEnvRequired" }

$result = [ordered]@{
    server = 'wechat-devtools-mcp-write'
    policy_path = $policyPath
    gates = [ordered]@{
        policy_enabled = $serviceEnabled
        review_gate_open = $reviewGateEnabled
        service_env = [ordered]@{
            name = $serviceEnvName
            required = $serviceEnvRequired
            actual = $serviceEnvActual
            ok = $serviceEnvOk
        }
        preview_tool_env = [ordered]@{
            name = $toolEnvName
            required = $toolEnvRequired
            actual = $toolEnvActual
            ok = $toolEnvOk
        }
    }
    blocked = ($blocks.Count -gt 0)
    blocked_by = @($blocks)
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
}
else {
    Write-Host "server: $($result.server)"
    Write-Host "blocked: $($result.blocked)"
    Write-Host "policy_enabled: $($result.gates.policy_enabled)"
    Write-Host "review_gate_open: $($result.gates.review_gate_open)"
    Write-Host "service_env: $serviceEnvName ($serviceEnvActual) required=$serviceEnvRequired ok=$serviceEnvOk"
    Write-Host "preview_tool_env: $toolEnvName ($toolEnvActual) required=$toolEnvRequired ok=$toolEnvOk"
    if ($result.blocked_by.Count -gt 0) {
        Write-Host "blocked_by: $($result.blocked_by -join '; ')"
    }
}

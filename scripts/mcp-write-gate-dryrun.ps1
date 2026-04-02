[CmdletBinding()]
param(
    [switch]$AsJson
)

$repoRoot = Split-Path $PSScriptRoot -Parent
$probeScript = Join-Path $PSScriptRoot 'mcp-write-gate-status.ps1'
$artifactPath = Join-Path $repoRoot 'artifacts\mcp-write-gate-dryrun-latest.json'

if (-not (Test-Path $probeScript)) {
    throw "Probe script not found: $probeScript"
}

function Invoke-ProbeCase {
    param(
        [string]$CaseName,
        [string]$ServiceEnvValue,
        [string]$ToolEnvValue
    )

    $oldService = [Environment]::GetEnvironmentVariable('WECHAT_WRITE_MCP_ENABLE')
    $oldTool = [Environment]::GetEnvironmentVariable('WECHAT_WRITE_TOOL_PREVIEW_ENABLE')

    try {
        if ($null -eq $ServiceEnvValue) {
            Remove-Item Env:WECHAT_WRITE_MCP_ENABLE -ErrorAction SilentlyContinue
        } else {
            $env:WECHAT_WRITE_MCP_ENABLE = $ServiceEnvValue
        }

        if ($null -eq $ToolEnvValue) {
            Remove-Item Env:WECHAT_WRITE_TOOL_PREVIEW_ENABLE -ErrorAction SilentlyContinue
        } else {
            $env:WECHAT_WRITE_TOOL_PREVIEW_ENABLE = $ToolEnvValue
        }

        $raw = powershell -ExecutionPolicy Bypass -File $probeScript -AsJson
        $status = $raw | ConvertFrom-Json
        return [ordered]@{
            case = $CaseName
            service_env = if ($null -eq $ServiceEnvValue) { '' } else { $ServiceEnvValue }
            tool_env = if ($null -eq $ToolEnvValue) { '' } else { $ToolEnvValue }
            blocked = [bool]$status.blocked
            blocked_by = @($status.blocked_by)
        }
    }
    finally {
        if ($null -eq $oldService -or $oldService -eq '') {
            Remove-Item Env:WECHAT_WRITE_MCP_ENABLE -ErrorAction SilentlyContinue
        } else {
            $env:WECHAT_WRITE_MCP_ENABLE = $oldService
        }

        if ($null -eq $oldTool -or $oldTool -eq '') {
            Remove-Item Env:WECHAT_WRITE_TOOL_PREVIEW_ENABLE -ErrorAction SilentlyContinue
        } else {
            $env:WECHAT_WRITE_TOOL_PREVIEW_ENABLE = $oldTool
        }
    }
}

$matrix = @(
    Invoke-ProbeCase -CaseName 'none' -ServiceEnvValue $null -ToolEnvValue $null
    Invoke-ProbeCase -CaseName 'service_only' -ServiceEnvValue '1' -ToolEnvValue $null
    Invoke-ProbeCase -CaseName 'tool_only' -ServiceEnvValue $null -ToolEnvValue '1'
    Invoke-ProbeCase -CaseName 'both_envs' -ServiceEnvValue '1' -ToolEnvValue '1'
)

$summary = [ordered]@{
    server = 'wechat-devtools-mcp-write'
    timestamp = (Get-Date).ToString('o')
    all_blocked = (@($matrix | Where-Object { -not $_.blocked }).Count -eq 0)
    matrix = $matrix
}

New-Item -ItemType Directory -Force -Path (Split-Path $artifactPath) | Out-Null
$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $artifactPath -Encoding UTF8

if ($AsJson) {
    $summary | ConvertTo-Json -Depth 8
}
else {
    Write-Host "server: $($summary.server)"
    Write-Host "all_blocked: $($summary.all_blocked)"
    foreach ($item in $summary.matrix) {
        Write-Host "$($item.case): blocked=$($item.blocked) blocked_by=$($item.blocked_by -join '; ')"
    }
    Write-Host "artifact: $artifactPath"
}

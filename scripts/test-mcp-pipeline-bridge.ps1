param()

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\test-common.ps1"

$bridgeScript = Join-Path $PSScriptRoot 'wechat-mcp-pipeline-bridge.ps1'
if (-not (Test-Path $bridgeScript)) {
    throw "Bridge script not found: $bridgeScript"
}

$raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $bridgeScript -Prompt 'build a product listing mini program' -Open false -Output json
if ($LASTEXITCODE -ne 0) {
    throw "Bridge script exited with code $LASTEXITCODE"
}
$jsonLine = @($raw | Where-Object { $_ -match '^\s*\{' }) | Select-Object -Last 1
if ([string]::IsNullOrWhiteSpace($jsonLine)) {
    throw 'Bridge script did not emit JSON output'
}
$result = $jsonLine | ConvertFrom-Json -ErrorAction Stop

Assert-In ([string]$result.status) @('success', 'repair_required', 'repair_exhausted', 'failed') 'pipeline bridge should return a structured status'
Assert-Equal ([string]$result.task_intent) 'generated-product' 'pipeline bridge should resolve generated-product task intent'
Assert-NotEmpty ([string]$result.task_family) 'pipeline bridge should return task family'
Assert-NotEmpty ([string]$result.route_mode) 'pipeline bridge should return route mode'
Assert-NotEmpty $result.project_path 'pipeline bridge should return a generated project path'

[pscustomobject]@{
    test = 'mcp-pipeline-bridge'
    pass = $true
    exit_code = 0
    status = [string]$result.status
    task_intent = [string]$result.task_intent
    task_family = [string]$result.task_family
    route_mode = [string]$result.route_mode
    project_path = [string]$result.project_path
    open_status = [string]$result.open_status
} | ConvertTo-Json -Depth 6

exit 0

param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$drillScript = Join-Path $PSScriptRoot 'mcp-write-preview-execution-drill.ps1'
Assert-True (Test-Path $drillScript) "execution drill script should exist"

$raw = & powershell -ExecutionPolicy Bypass -File $drillScript -AsJson 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -and $raw -match 'spawn EPERM') {
    New-TestResult -Name 'mcp-write-preview-execution-drill' -Data @{
        pass = $true
        exit_code = 0
        skipped = $true
        reason = 'environment_spawn_eperm'
    }
    return
}
try {
    $json = $raw | ConvertFrom-Json
}
catch {
    throw "execution drill parse failed: $raw"
}

Assert-Equal $json.blocked_status 'blocked_by_execution_flag' 'execute mode without flag should be blocked'
Assert-Equal $json.permitted_status 'execution_permitted' 'execute mode with flag should be permitted'
Assert-Equal $json.execution_ready $true 'permitted mode should mark execution_ready'
Assert-Equal $json.execution_status 'pending' 'execution status should be pending before tool runtime executes preview'

New-TestResult -Name 'mcp-write-preview-execution-drill' -Data @{
    pass = $true
    exit_code = 0
    blocked_status = $json.blocked_status
    permitted_status = $json.permitted_status
}

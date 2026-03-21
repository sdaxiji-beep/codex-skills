param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\mcp-write-preview.ps1"

function Assert-OutputSchema {
    param([hashtable]$Result, [string]$CaseName)

    $required = @('status', 'request_id', 'project_path', 'gate', 'preview', 'audit', 'error')
    foreach ($k in $required) {
        Assert-True ($Result.Contains($k)) "$CaseName missing field: $k"
    }
}

function Assert-AuditExists {
    param([hashtable]$Result, [string]$CaseName)

    Assert-True ($null -ne $Result.audit) "$CaseName audit missing"
    Assert-NotEmpty $Result.audit.record_path "$CaseName audit path missing"
    Assert-True (Test-Path $Result.audit.record_path) "$CaseName audit file not found"
}

$repoRoot = Split-Path $PSScriptRoot -Parent
$sandboxProject = Join-Path $repoRoot 'sandbox\fake-project'
$realProject = Join-Path $repoRoot 'sandbox\preview-allowed-project'
$localReleaseConfigPath = Join-Path $repoRoot 'config\local-release.config.json'
$backupLocalReleaseConfig = $null
$origForceGate = $env:MCP_PREVIEW_FORCE_FAST_GATE_FAIL
$origForcePreviewFail = $env:MCP_PREVIEW_FORCE_PREVIEW_FAIL
$origSkipFastGate = $env:MCP_PREVIEW_SKIP_FAST_GATE

try {
    if (Test-Path $localReleaseConfigPath) {
        $backupLocalReleaseConfig = Get-Content $localReleaseConfigPath -Raw
    }
    New-Item -ItemType Directory -Force -Path $realProject | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path $localReleaseConfigPath -Parent) | Out-Null
    @{
        appid       = 'wxexamplepreview0001'
        projectRoot = $realProject
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $localReleaseConfigPath -Encoding UTF8

    Remove-Item Env:MCP_PREVIEW_FORCE_FAST_GATE_FAIL -ErrorAction SilentlyContinue
    Remove-Item Env:MCP_PREVIEW_FORCE_PREVIEW_FAIL -ErrorAction SilentlyContinue
    $env:MCP_PREVIEW_SKIP_FAST_GATE = '1'

    $a = Invoke-McpPreviewProject -ProjectPath $sandboxProject -RequireConfirm $true -RequestId 'case-a-success'
    Assert-OutputSchema -Result $a -CaseName 'A'
    Assert-Equal $a.status 'success' 'A expected success'
    Assert-True ($a.gate.fast_gate_passed) 'A fast gate should pass'
    Assert-True (Test-Path $a.preview.qrcode_path) 'A preview artifact should exist'
    Assert-AuditExists -Result $a -CaseName 'A'

    $env:MCP_PREVIEW_FORCE_FAST_GATE_FAIL = '1'
    $b = Invoke-McpPreviewProject -ProjectPath $sandboxProject -RequireConfirm $true -RequestId 'case-b-fast-gate-fail'
    Assert-OutputSchema -Result $b -CaseName 'B'
    Assert-Equal $b.status 'denied' 'B expected denied'
    Assert-Equal $b.error.code 'fast_gate_failed' 'B expected fast_gate_failed'
    Assert-AuditExists -Result $b -CaseName 'B'
    Remove-Item Env:MCP_PREVIEW_FORCE_FAST_GATE_FAIL -ErrorAction SilentlyContinue

    $c = Invoke-McpPreviewProject -ProjectPath 'C:\not-allowed' -RequireConfirm $true -RequestId 'case-c-path-deny'
    Assert-OutputSchema -Result $c -CaseName 'C'
    Assert-Equal $c.status 'denied' 'C expected denied'
    Assert-Equal $c.error.code 'path_not_allowed' 'C expected path_not_allowed'
    Assert-AuditExists -Result $c -CaseName 'C'

    $d = Invoke-McpPreviewProject -ProjectPath $sandboxProject -RequireConfirm $false -RequestId 'case-d-confirmation-deny'
    Assert-OutputSchema -Result $d -CaseName 'D'
    Assert-Equal $d.status 'denied' 'D expected denied'
    Assert-Equal $d.error.code 'confirmation_required' 'D expected confirmation_required'
    Assert-AuditExists -Result $d -CaseName 'D'

    $env:MCP_PREVIEW_FORCE_PREVIEW_FAIL = '1'
    $e = Invoke-McpPreviewProject -ProjectPath $sandboxProject -RequireConfirm $true -RequestId 'case-e-preview-fail'
    Assert-OutputSchema -Result $e -CaseName 'E'
    Assert-Equal $e.status 'failed' 'E expected failed'
    Assert-Equal $e.error.code 'preview_command_failed' 'E expected preview_command_failed'
    Assert-AuditExists -Result $e -CaseName 'E'
    Remove-Item Env:MCP_PREVIEW_FORCE_PREVIEW_FAIL -ErrorAction SilentlyContinue

    $f = Invoke-McpPreviewProject -ProjectPath $realProject -RequireConfirm $true -RequestId 'case-f-real-project-success'
    Assert-OutputSchema -Result $f -CaseName 'F'
    Assert-Equal $f.status 'success' 'F expected success'
    Assert-True ($f.gate.fast_gate_passed) 'F fast gate should pass'
    Assert-AuditExists -Result $f -CaseName 'F'

    New-TestResult -Name 'mcp-write-preview' -Data @{
        pass = $true
        exit_code = 0
        case_a = $a.status
        case_b = $b.error.code
        case_c = $c.error.code
        case_d = $d.error.code
        case_e = $e.error.code
        case_f = $f.status
        audits = @(
            $a.audit.record_path,
            $b.audit.record_path,
            $c.audit.record_path,
            $d.audit.record_path,
            $e.audit.record_path,
            $f.audit.record_path
        )
    }
}
finally {
    if ($null -ne $backupLocalReleaseConfig) {
        Set-Content -Path $localReleaseConfigPath -Value $backupLocalReleaseConfig -Encoding UTF8
    }
    else {
        Remove-Item $localReleaseConfigPath -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $realProject -Recurse -Force -ErrorAction SilentlyContinue

    if ($null -ne $origForceGate) {
        $env:MCP_PREVIEW_FORCE_FAST_GATE_FAIL = $origForceGate
    }
    else {
        Remove-Item Env:MCP_PREVIEW_FORCE_FAST_GATE_FAIL -ErrorAction SilentlyContinue
    }

    if ($null -ne $origForcePreviewFail) {
        $env:MCP_PREVIEW_FORCE_PREVIEW_FAIL = $origForcePreviewFail
    }
    else {
        Remove-Item Env:MCP_PREVIEW_FORCE_PREVIEW_FAIL -ErrorAction SilentlyContinue
    }

    if ($null -ne $origSkipFastGate) {
        $env:MCP_PREVIEW_SKIP_FAST_GATE = $origSkipFastGate
    }
    else {
        Remove-Item Env:MCP_PREVIEW_SKIP_FAST_GATE -ErrorAction SilentlyContinue
    }
}

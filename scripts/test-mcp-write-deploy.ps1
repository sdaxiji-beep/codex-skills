param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\mcp-write-deploy.ps1"

function Assert-OutputSchema {
    param([hashtable]$Result, [string]$CaseName)
    $required = @('status', 'request_id', 'func_name', 'gate', 'deploy', 'audit', 'error')
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

$origForceFull = $env:MCP_DEPLOY_FORCE_FULL_FAIL
$origForceDeploy = $env:MCP_DEPLOY_FORCE_DEPLOY_FAIL
$origForceDeploySuccess = $env:MCP_DEPLOY_FORCE_DEPLOY_SUCCESS
$origSkipFullGate = $env:MCP_DEPLOY_SKIP_FULL_GATE
$origAutoConfirm = $env:DEPLOY_AUTO_CONFIRM

try {
    Remove-Item Env:MCP_DEPLOY_FORCE_FULL_FAIL -ErrorAction SilentlyContinue
    Remove-Item Env:MCP_DEPLOY_FORCE_DEPLOY_FAIL -ErrorAction SilentlyContinue
    Remove-Item Env:MCP_DEPLOY_FORCE_DEPLOY_SUCCESS -ErrorAction SilentlyContinue
    $env:MCP_DEPLOY_SKIP_FULL_GATE = '1'
    $env:DEPLOY_AUTO_CONFIRM = 'yes'

    # A: success
    $env:MCP_DEPLOY_FORCE_DEPLOY_SUCCESS = '1'
    $a = Invoke-McpDeployCloudFunction -FuncName 'timerCancelOrder' -RequireConfirm $true -RequestId 'deploy-case-a-success' -ValidationMode 'full'
    Remove-Item Env:MCP_DEPLOY_FORCE_DEPLOY_SUCCESS -ErrorAction SilentlyContinue
    Assert-OutputSchema -Result $a -CaseName 'A'
    Assert-Equal $a.status 'success' 'A expected success'
    Assert-True ($a.gate.full_gate_passed) 'A full gate should pass'
    Assert-Equal $a.deploy.cloud_status 'Active' 'A cloud status should be Active'
    Assert-AuditExists -Result $a -CaseName 'A'

    # B: function not allowlisted
    $b = Invoke-McpDeployCloudFunction -FuncName 'notAllowedFunc' -RequireConfirm $true -RequestId 'deploy-case-b-denied' -ValidationMode 'full'
    Assert-OutputSchema -Result $b -CaseName 'B'
    Assert-Equal $b.status 'denied' 'B expected denied'
    Assert-Equal $b.error.code 'func_not_allowed' 'B expected func_not_allowed'
    Assert-AuditExists -Result $b -CaseName 'B'

    # C: require_confirm false
    $c = Invoke-McpDeployCloudFunction -FuncName 'timerCancelOrder' -RequireConfirm $false -RequestId 'deploy-case-c-confirm' -ValidationMode 'full'
    Assert-OutputSchema -Result $c -CaseName 'C'
    Assert-Equal $c.status 'denied' 'C expected denied'
    Assert-Equal $c.error.code 'confirmation_required' 'C expected confirmation_required'
    Assert-AuditExists -Result $c -CaseName 'C'

    # D: full gate fail
    Remove-Item Env:MCP_DEPLOY_SKIP_FULL_GATE -ErrorAction SilentlyContinue
    $env:MCP_DEPLOY_FORCE_FULL_FAIL = '1'
    $d = Invoke-McpDeployCloudFunction -FuncName 'timerCancelOrder' -RequireConfirm $true -RequestId 'deploy-case-d-full-fail' -ValidationMode 'full'
    Assert-OutputSchema -Result $d -CaseName 'D'
    Assert-Equal $d.status 'denied' 'D expected denied'
    Assert-Equal $d.error.code 'full_gate_failed' 'D expected full_gate_failed'
    Assert-AuditExists -Result $d -CaseName 'D'
    Remove-Item Env:MCP_DEPLOY_FORCE_FULL_FAIL -ErrorAction SilentlyContinue
    $env:MCP_DEPLOY_SKIP_FULL_GATE = '1'

    # E: deploy command fail
    $env:MCP_DEPLOY_FORCE_DEPLOY_FAIL = '1'
    $e = Invoke-McpDeployCloudFunction -FuncName 'timerCancelOrder' -RequireConfirm $true -RequestId 'deploy-case-e-deploy-fail' -ValidationMode 'full'
    Assert-OutputSchema -Result $e -CaseName 'E'
    Assert-Equal $e.status 'failed' 'E expected failed'
    Assert-Equal $e.error.code 'deploy_command_failed' 'E expected deploy_command_failed'
    Assert-AuditExists -Result $e -CaseName 'E'
    Remove-Item Env:MCP_DEPLOY_FORCE_DEPLOY_FAIL -ErrorAction SilentlyContinue

    New-TestResult -Name 'mcp-write-deploy' -Data @{
        pass = $true
        exit_code = 0
        case_a = $a.status
        case_b = $b.error.code
        case_c = $c.error.code
        case_d = $d.error.code
        case_e = $e.error.code
        audits = @(
            $a.audit.record_path,
            $b.audit.record_path,
            $c.audit.record_path,
            $d.audit.record_path,
            $e.audit.record_path
        )
    }
}
finally {
    if ($null -ne $origForceFull) { $env:MCP_DEPLOY_FORCE_FULL_FAIL = $origForceFull } else { Remove-Item Env:MCP_DEPLOY_FORCE_FULL_FAIL -ErrorAction SilentlyContinue }
    if ($null -ne $origForceDeploy) { $env:MCP_DEPLOY_FORCE_DEPLOY_FAIL = $origForceDeploy } else { Remove-Item Env:MCP_DEPLOY_FORCE_DEPLOY_FAIL -ErrorAction SilentlyContinue }
    if ($null -ne $origForceDeploySuccess) { $env:MCP_DEPLOY_FORCE_DEPLOY_SUCCESS = $origForceDeploySuccess } else { Remove-Item Env:MCP_DEPLOY_FORCE_DEPLOY_SUCCESS -ErrorAction SilentlyContinue }
    if ($null -ne $origSkipFullGate) { $env:MCP_DEPLOY_SKIP_FULL_GATE = $origSkipFullGate } else { Remove-Item Env:MCP_DEPLOY_SKIP_FULL_GATE -ErrorAction SilentlyContinue }
    if ($null -ne $origAutoConfirm) { $env:DEPLOY_AUTO_CONFIRM = $origAutoConfirm } else { Remove-Item Env:DEPLOY_AUTO_CONFIRM -ErrorAction SilentlyContinue }
}

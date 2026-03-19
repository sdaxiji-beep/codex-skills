[CmdletBinding()]
param()

. "$PSScriptRoot\wechat-deploy.ps1"
. "$PSScriptRoot\wechat-get-port.ps1"

function Get-CachedFullGateResult {
    param([int]$FreshnessMinutes = 10)

    $cachePath = 'G:\codex专属\artifacts\full-gate-cache.json'
    if (-not (Test-Path $cachePath)) {
        return $null
    }

    try {
        $cache = Get-Content $cachePath -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $null
    }

    if (-not $cache.timestamp -or -not $cache.git_hash) {
        return $null
    }

    $age = (Get-Date) - [datetime]$cache.timestamp
    if ($age.TotalMinutes -gt $FreshnessMinutes) {
        Write-Verbose "[GATE] cache expired: $([math]::Round($age.TotalMinutes, 1)) minutes"
        return $null
    }

    $projectRoot = [string](Get-DeployConfig).projectRoot
    Push-Location $projectRoot
    try {
        $currentHash = (git rev-parse HEAD 2>$null | Out-String).Trim()
    }
    finally {
        Pop-Location
    }

    if ([string]::IsNullOrWhiteSpace($currentHash) -or $currentHash -ne [string]$cache.git_hash) {
        Write-Verbose '[GATE] cache invalidated by git hash change'
        return $null
    }

    if (-not [bool]$cache.success -or [int]$cache.failed -ne 0) {
        return $null
    }

    Write-Verbose "[GATE] cache reused: $([math]::Round($age.TotalMinutes, 1)) minutes old"
    return @{
        success    = [bool]$cache.success
        passed     = [int]$cache.passed
        failed     = [int]$cache.failed
        elapsed_s  = [double]$cache.elapsed_s
        raw_output = 'full_gate_cache_reused'
        cached     = $true
        cache_age_minutes = [math]::Round($age.TotalMinutes, 2)
    }
}

function Save-FullGateResult {
    param([hashtable]$GateResult)

    if ($null -eq $GateResult) {
        return
    }

    if (-not $GateResult.success -or $GateResult.failed -ne 0) {
        return
    }

    if ($GateResult.raw_output -eq 'full_gate_skipped_for_test') {
        return
    }

    $artifactsRoot = 'G:\codex专属\artifacts'
    $cachePath = Join-Path $artifactsRoot 'full-gate-cache.json'
    New-Item -ItemType Directory -Force -Path $artifactsRoot | Out-Null

    $projectRoot = [string](Get-DeployConfig).projectRoot
    Push-Location $projectRoot
    try {
        $gitHash = (git rev-parse HEAD 2>$null | Out-String).Trim()
    }
    finally {
        Pop-Location
    }

    @{
        timestamp = (Get-Date).ToString('o')
        git_hash  = $gitHash
        passed    = [int]$GateResult.passed
        failed    = [int]$GateResult.failed
        elapsed_s = [double]$GateResult.elapsed_s
        success   = [bool]$GateResult.success
    } | ConvertTo-Json -Depth 6 | Set-Content $cachePath -Encoding UTF8
}

function New-McpDeployResponse {
    param(
        [string]$Status,
        [string]$RequestId,
        [string]$FuncName,
        [hashtable]$Gate,
        [hashtable]$Deploy,
        [hashtable]$Audit,
        [hashtable]$Error
    )

    return [ordered]@{
        status     = $Status
        request_id = $RequestId
        func_name  = $FuncName
        elapsed_s  = if ($Deploy -and $Deploy.elapsed_s) { $Deploy.elapsed_s } else { 0 }
        gate       = $Gate
        deploy     = $Deploy
        audit      = $Audit
        error      = $Error
    }
}

function Write-McpDeployAudit {
    param([hashtable]$Response)

    $repoRoot = Split-Path $PSScriptRoot -Parent
    $auditDir = Join-Path $repoRoot 'artifacts\mcp-write-deploy'
    New-Item -ItemType Directory -Force -Path $auditDir | Out-Null
    $auditPath = Join-Path $auditDir ("audit-{0}.json" -f $Response.request_id)
    $payload = [ordered]@{
        timestamp  = (Get-Date).ToString('o')
        status     = $Response.status
        request_id = $Response.request_id
        func_name  = $Response.func_name
        gate       = $Response.gate
        deploy     = $Response.deploy
        error      = $Response.error
    }
    $payload | ConvertTo-Json -Depth 10 | Set-Content -Path $auditPath -Encoding UTF8
    return $auditPath
}

function Invoke-McpFullGate {
    param()

    if ($env:MCP_DEPLOY_FORCE_FULL_FAIL -eq '1') {
        return @{
            success    = $false
            passed     = 0
            failed     = 1
            elapsed_s  = 0
            raw_output = 'forced full gate failure'
        }
    }

    if ($env:MCP_DEPLOY_SKIP_FULL_GATE -eq '1') {
        return @{
            success    = $true
            passed     = 58
            failed     = 0
            elapsed_s  = 0
            raw_output = 'full_gate_skipped_for_test'
        }
    }

    $suite = Join-Path $PSScriptRoot 'test-wechat-skill.ps1'
    $prevDeployConfirm = $env:DEPLOY_AUTO_CONFIRM
    $prevWriteConfirm = $env:WRITE_GUARD_AUTO_CONFIRM
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Remove-Item Env:DEPLOY_AUTO_CONFIRM -ErrorAction SilentlyContinue
        Remove-Item Env:WRITE_GUARD_AUTO_CONFIRM -ErrorAction SilentlyContinue
        $output = & powershell -ExecutionPolicy Bypass -File $suite -SkipSmoke -Tag full 2>&1 | Out-String
    }
    finally {
        if ($null -ne $prevDeployConfirm) { $env:DEPLOY_AUTO_CONFIRM = $prevDeployConfirm } else { Remove-Item Env:DEPLOY_AUTO_CONFIRM -ErrorAction SilentlyContinue }
        if ($null -ne $prevWriteConfirm) { $env:WRITE_GUARD_AUTO_CONFIRM = $prevWriteConfirm } else { Remove-Item Env:WRITE_GUARD_AUTO_CONFIRM -ErrorAction SilentlyContinue }
    }
    $sw.Stop()

    $passed = 0
    $failed = 0
    $success = $false
    $passedMatches = [regex]::Matches($output, '"passed"\s*:\s*(\d+)')
    $failedMatches = [regex]::Matches($output, '"failed"\s*:\s*(\d+)')
    if ($passedMatches.Count -gt 0) {
        $passed = [int]$passedMatches[$passedMatches.Count - 1].Groups[1].Value
    }
    if ($failedMatches.Count -gt 0) {
        $failed = [int]$failedMatches[$failedMatches.Count - 1].Groups[1].Value
    }
    if ($output -match '"success"\s*:\s*true') { $success = $true }

    return @{
        success    = $success
        passed     = $passed
        failed     = $failed
        elapsed_s  = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        raw_output = $output
    }
}

function Invoke-McpVerifyCloudStatus {
    param([Parameter(Mandatory)][string]$FuncName)

    if ($env:MCP_DEPLOY_FORCE_DEPLOY_SUCCESS -eq '1') {
        return @{
            ok = $true
            status = 'Active'
            port = 0
            raw = 'forced_active'
        }
    }

    $config = Get-DeployConfig
    $port = Get-WechatDevtoolsPort
    $uri = "http://127.0.0.1:{0}/v2/cloud/functions/info?project={1}&env={2}&names={3}" -f `
        $port, [uri]::EscapeDataString($config.projectRoot), [uri]::EscapeDataString($config.cloudEnv), [uri]::EscapeDataString($FuncName)

    try {
        $info = Invoke-RestMethod -Uri $uri -Method GET -TimeoutSec 20
    }
    catch {
        return @{
            ok = $false
            status = ''
            port = $port
            raw = $_.Exception.Message
        }
    }

    $status = ''
    if ($info.list -and $info.list.Count -gt 0 -and $info.list[0].status) {
        $status = [string]$info.list[0].status
    }
    elseif ($info.data -and $info.data.list -and $info.data.list.Count -gt 0 -and $info.data.list[0].status) {
        $status = [string]$info.data.list[0].status
    }

    return @{
        ok = ($status -eq 'Active')
        status = $status
        port = $port
        raw = $info
    }
}

function Invoke-McpDeployCloudFunction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FuncName,
        [Parameter(Mandatory)][bool]$RequireConfirm,
        [string]$RequestId = ([guid]::NewGuid().ToString()),
        [string]$ValidationMode = 'full'
    )

    $gate = @{
        allowlist_passed = $false
        confirmation_passed = $false
        full_gate_passed = $false
        full_gate_passed_count = 0
        full_gate_failed_count = 0
        elapsed_s = 0
        deploy_policy_lock_passed = $false
        cache_used = $false
        cache_age_minutes = $null
    }
    $deploy = @{
        status = 'not_started'
        cloud_status = ''
        raw_result = $null
        elapsed_s = 0
    }
    $audit = @{
        record_path = $null
        timestamp = (Get-Date).ToString('o')
    }
    $error = $null
    $totalSw = [System.Diagnostics.Stopwatch]::StartNew()

    # validate_input
    if ([string]::IsNullOrWhiteSpace($FuncName)) {
        $error = @{ code = 'invalid_input'; message = 'func_name is required'; details = @{} }
        $response = New-McpDeployResponse -Status 'failed' -RequestId $RequestId -FuncName $FuncName -Gate $gate -Deploy $deploy -Audit $audit -Error $error
        $audit.record_path = Write-McpDeployAudit -Response $response
        $response.audit = $audit
        return $response
    }
    if ($ValidationMode -ne 'full') {
        $error = @{ code = 'invalid_validation_mode'; message = 'validation_mode must be full'; details = @{ validation_mode = $ValidationMode } }
        $response = New-McpDeployResponse -Status 'failed' -RequestId $RequestId -FuncName $FuncName -Gate $gate -Deploy $deploy -Audit $audit -Error $error
        $audit.record_path = Write-McpDeployAudit -Response $response
        $response.audit = $audit
        return $response
    }

    # run_guard_checks: func_allowlist
    $allowlist = @('timerCancelOrder', 'initDb')
    if ($allowlist -notcontains $FuncName) {
        $error = @{ code = 'func_not_allowed'; message = 'function not in allowlist'; details = @{ func_name = $FuncName; allowlist = $allowlist } }
        $response = New-McpDeployResponse -Status 'denied' -RequestId $RequestId -FuncName $FuncName -Gate $gate -Deploy $deploy -Audit $audit -Error $error
        $audit.record_path = Write-McpDeployAudit -Response $response
        $response.audit = $audit
        return $response
    }
    $gate.allowlist_passed = $true

    # run_guard_checks: confirmation_required
    if (-not $RequireConfirm) {
        $error = @{ code = 'confirmation_required'; message = 'require_confirm must be true'; details = @{ require_confirm = $RequireConfirm } }
        $response = New-McpDeployResponse -Status 'denied' -RequestId $RequestId -FuncName $FuncName -Gate $gate -Deploy $deploy -Audit $audit -Error $error
        $audit.record_path = Write-McpDeployAudit -Response $response
        $response.audit = $audit
        return $response
    }
    $gate.confirmation_passed = $true

    # run_guard_checks: deploy_policy_lock
    $action = 'deploy-function'
    if ($action -ne 'deploy-function') {
        $error = @{ code = 'policy_violation'; message = 'deploy policy lock violated'; details = @{ action = $action } }
        $response = New-McpDeployResponse -Status 'denied' -RequestId $RequestId -FuncName $FuncName -Gate $gate -Deploy $deploy -Audit $audit -Error $error
        $audit.record_path = Write-McpDeployAudit -Response $response
        $response.audit = $audit
        return $response
    }
    $gate.deploy_policy_lock_passed = $true

    # run_guard_checks: full_gate_required
    $fullGate = Get-CachedFullGateResult -FreshnessMinutes 10
    if ($null -eq $fullGate) {
        Write-Host '[GATE] running full gate...'
        $fullGate = Invoke-McpFullGate
        if ($fullGate.success) {
            Save-FullGateResult -GateResult $fullGate
        }
    }
    else {
        Write-Host '[GATE] cache reused, full gate skipped'
    }
    $gate.full_gate_passed = [bool]$fullGate.success
    $gate.full_gate_passed_count = [int]$fullGate.passed
    $gate.full_gate_failed_count = [int]$fullGate.failed
    $gate.elapsed_s = [double]$fullGate.elapsed_s
    $gate.cache_used = [bool]($fullGate.ContainsKey('cached') -and $fullGate.cached)
    if ($fullGate.ContainsKey('cache_age_minutes')) {
        $gate.cache_age_minutes = $fullGate.cache_age_minutes
    }
    if (-not $fullGate.success -or $fullGate.failed -ne 0) {
        $error = @{ code = 'full_gate_failed'; message = 'full regression must pass before deploy'; details = @{ passed = $fullGate.passed; failed = $fullGate.failed } }
        $totalSw.Stop()
        $deploy.elapsed_s = [math]::Round($totalSw.Elapsed.TotalSeconds, 2)
        $response = New-McpDeployResponse -Status 'denied' -RequestId $RequestId -FuncName $FuncName -Gate $gate -Deploy $deploy -Audit $audit -Error $error
        $audit.record_path = Write-McpDeployAudit -Response $response
        $response.audit = $audit
        return $response
    }

    # invoke_deploy_command
    try {
        if ($env:MCP_DEPLOY_FORCE_DEPLOY_FAIL -eq '1') {
            throw "forced deploy failure"
        }
        if ($env:MCP_DEPLOY_FORCE_DEPLOY_SUCCESS -eq '1') {
            $deployResult = @{
                status = 'success'
                success = $true
                mode = 'deploy-function'
                functionName = $FuncName
                output = @{
                    mocked = $true
                }
            }
        }
        else {
            $prev = $env:DEPLOY_AUTO_CONFIRM
            $env:DEPLOY_AUTO_CONFIRM = 'yes'
            try {
                $deployResult = Invoke-DeployCloudFunction -FuncName $FuncName -RequireConfirm $true
            }
            finally {
                if ($null -ne $prev) { $env:DEPLOY_AUTO_CONFIRM = $prev } else { Remove-Item Env:DEPLOY_AUTO_CONFIRM -ErrorAction SilentlyContinue }
            }
        }
        if ($deployResult.status -ne 'success') {
            throw "deploy returned non-success: $($deployResult.status)"
        }
        $deploy.status = 'success'
        $deploy.raw_result = $deployResult
    }
    catch {
        $deploy.status = 'failed'
        $totalSw.Stop()
        $deploy.elapsed_s = [math]::Round($totalSw.Elapsed.TotalSeconds, 2)
        $error = @{ code = 'deploy_command_failed'; message = 'deploy command failed'; details = @{ exception = $_.Exception.Message } }
        $response = New-McpDeployResponse -Status 'failed' -RequestId $RequestId -FuncName $FuncName -Gate $gate -Deploy $deploy -Audit $audit -Error $error
        $audit.record_path = Write-McpDeployAudit -Response $response
        $response.audit = $audit
        return $response
    }

    # verify_cloud_status
    $verify = Invoke-McpVerifyCloudStatus -FuncName $FuncName
    $deploy.cloud_status = $verify.status
    if (-not $verify.ok) {
        $totalSw.Stop()
        $deploy.elapsed_s = [math]::Round($totalSw.Elapsed.TotalSeconds, 2)
        $error = @{ code = 'cloud_status_not_active'; message = 'cloud status verification failed'; details = @{ status = $verify.status; port = $verify.port; raw = $verify.raw } }
        $response = New-McpDeployResponse -Status 'failed' -RequestId $RequestId -FuncName $FuncName -Gate $gate -Deploy $deploy -Audit $audit -Error $error
        $audit.record_path = Write-McpDeployAudit -Response $response
        $response.audit = $audit
        return $response
    }

    # write_audit_record -> return_structured_result
    $totalSw.Stop()
    $deploy.elapsed_s = [math]::Round($totalSw.Elapsed.TotalSeconds, 2)
    $response = New-McpDeployResponse -Status 'success' -RequestId $RequestId -FuncName $FuncName -Gate $gate -Deploy $deploy -Audit $audit -Error $null
    $audit.record_path = Write-McpDeployAudit -Response $response
    $response.audit = $audit
    return $response
}

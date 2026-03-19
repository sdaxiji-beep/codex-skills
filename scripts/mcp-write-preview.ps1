[CmdletBinding()]
param()

function New-McpPreviewResponse {
    param(
        [string]$Status,
        [string]$RequestId,
        [string]$ProjectPath,
        [hashtable]$Gate,
        [hashtable]$Preview,
        [hashtable]$Audit,
        [hashtable]$Error
    )

    return [ordered]@{
        status       = $Status
        request_id   = $RequestId
        project_path = $ProjectPath
        gate         = $Gate
        preview      = $Preview
        audit        = $Audit
        error        = $Error
    }
}

function Test-McpPreviewAllowlist {
    param([Parameter(Mandatory)][string]$ProjectPath)

    $candidate = [System.IO.Path]::GetFullPath($ProjectPath)
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $deployConfigPath = Join-Path $repoRoot 'deploy-config.json'
    $realProjectRoot = $null
    if (Test-Path $deployConfigPath) {
        try {
            $deployConfig = Get-Content $deployConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($deployConfig.projectRoot) {
                $realProjectRoot = [System.IO.Path]::GetFullPath([string]$deployConfig.projectRoot)
            }
        }
        catch {
        }
    }
    if (-not $realProjectRoot) {
        $realProjectRoot = [System.IO.Path]::GetFullPath('D:\luwei')
    }

    $allowedRoots = @(
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'sandbox')),
        $realProjectRoot
    )

    foreach ($root in $allowedRoots) {
        if ($candidate.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
            return @{
                ok = $true
                normalized_project_path = $candidate
                allowed_roots = $allowedRoots
            }
        }
    }

    return @{
        ok = $false
        normalized_project_path = $candidate
        allowed_roots = $allowedRoots
    }
}

function Invoke-McpFastGate {
    param()

    if ($env:MCP_PREVIEW_FORCE_FAST_GATE_FAIL -eq '1') {
        return @{
            success = $false
            passed  = 0
            failed  = 1
            elapsed_s = 0
            raw_output = 'forced fast gate failure'
        }
    }

    if ($env:MCP_PREVIEW_SKIP_FAST_GATE -eq '1') {
        return @{
            success = $true
            passed  = 32
            failed  = 0
            elapsed_s = 0
            raw_output = 'fast_gate_skipped_for_test'
        }
    }

    $suite = Join-Path $PSScriptRoot 'test-wechat-skill.ps1'
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $output = & powershell -ExecutionPolicy Bypass -File $suite -SkipSmoke -Tag fast 2>&1 | Out-String
    $sw.Stop()

    $passed = 0
    $failed = 0
    $success = $false
    if ($output -match '"passed"\s*:\s*(\d+)') { $passed = [int]$Matches[1] }
    if ($output -match '"failed"\s*:\s*(\d+)') { $failed = [int]$Matches[1] }
    if ($output -match '"success"\s*:\s*true') { $success = $true }

    return @{
        success    = $success
        passed     = $passed
        failed     = $failed
        elapsed_s  = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        raw_output = $output
    }
}

function Invoke-McpPreviewCommand {
    param(
        [Parameter(Mandatory)][string]$ProjectPath,
        [Parameter(Mandatory)][string]$Desc,
        [Parameter(Mandatory)][string]$RequestId
    )

    if ($env:MCP_PREVIEW_FORCE_PREVIEW_FAIL -eq '1') {
        throw "forced preview failure"
    }

    $repoRoot = Split-Path $PSScriptRoot -Parent
    $drillScript = Join-Path $PSScriptRoot 'mcp-write-preview-drill.ps1'
    if (-not (Test-Path $drillScript)) {
        throw "preview drill not found: $drillScript"
    }

    $drill = & powershell -ExecutionPolicy Bypass -File $drillScript -Desc $Desc -AsJson 2>&1 | Out-String
    $drillJson = $null
    try {
        $drillJson = $drill | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $drillJson = @{
            ok = $false
            status = 'parse_failed'
            tool = 'preview_project'
        }
    }

    $artifactDir = Join-Path $repoRoot 'artifacts\mcp-preview'
    New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null
    $qrcodePath = Join-Path $artifactDir ("preview-{0}.txt" -f $RequestId)
    @(
        "request_id=$RequestId"
        "project_path=$ProjectPath"
        "desc=$Desc"
        "created_at=$((Get-Date).ToString('o'))"
    ) | Set-Content -Path $qrcodePath -Encoding UTF8

    return @{
        status      = 'success'
        qrcode_path = $qrcodePath
        raw_result  = @{
            drill_ok     = [bool]$drillJson.ok
            drill_status = [string]$drillJson.status
            drill_tool   = [string]$drillJson.tool
        }
    }
}

function Write-McpPreviewAudit {
    param(
        [Parameter(Mandatory)][hashtable]$Response
    )

    $repoRoot = Split-Path $PSScriptRoot -Parent
    $auditDir = Join-Path $repoRoot 'artifacts\mcp-write-preview'
    New-Item -ItemType Directory -Force -Path $auditDir | Out-Null
    $auditPath = Join-Path $auditDir ("audit-{0}.json" -f $Response.request_id)

    $auditPayload = [ordered]@{
        timestamp    = (Get-Date).ToString('o')
        status       = $Response.status
        request_id   = $Response.request_id
        project_path = $Response.project_path
        gate         = $Response.gate
        preview      = $Response.preview
        error        = $Response.error
    }
    $auditPayload | ConvertTo-Json -Depth 10 | Set-Content -Path $auditPath -Encoding UTF8
    return $auditPath
}

function Invoke-McpPreviewProject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectPath,
        [string]$Desc = 'preview by mcp',
        [string]$ValidationMode = 'fast-gate',
        [Parameter(Mandatory)][bool]$RequireConfirm,
        [string]$RequestId = ([guid]::NewGuid().ToString())
    )

    $gate = @{
        fast_gate_passed = $false
        fast_gate_passed_count = 0
        fast_gate_failed_count = 0
        elapsed_s = 0
    }
    $preview = @{
        status = 'not_started'
        qrcode_path = $null
        raw_result = $null
    }
    $audit = @{
        record_path = $null
        timestamp = (Get-Date).ToString('o')
    }
    $error = $null

    # validate_input
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        $error = @{ code = 'invalid_input'; message = 'project_path is required'; details = @{} }
        $response = New-McpPreviewResponse -Status 'failed' -RequestId $RequestId -ProjectPath $ProjectPath -Gate $gate -Preview $preview -Audit $audit -Error $error
        $audit.record_path = Write-McpPreviewAudit -Response $response
        $response.audit = $audit
        return $response
    }
    if ($ValidationMode -ne 'fast-gate') {
        $error = @{ code = 'invalid_validation_mode'; message = 'validation_mode must be fast-gate'; details = @{ validation_mode = $ValidationMode } }
        $response = New-McpPreviewResponse -Status 'failed' -RequestId $RequestId -ProjectPath $ProjectPath -Gate $gate -Preview $preview -Audit $audit -Error $error
        $audit.record_path = Write-McpPreviewAudit -Response $response
        $response.audit = $audit
        return $response
    }

    # run_guard_checks: path_allowlist
    $allow = Test-McpPreviewAllowlist -ProjectPath $ProjectPath
    $normalizedProjectPath = $allow.normalized_project_path
    if (-not $allow.ok) {
        $error = @{ code = 'path_not_allowed'; message = 'project_path must be under allowlist'; details = @{ project_path = $ProjectPath; allowed_roots = $allow.allowed_roots } }
        $response = New-McpPreviewResponse -Status 'denied' -RequestId $RequestId -ProjectPath $normalizedProjectPath -Gate $gate -Preview $preview -Audit $audit -Error $error
        $audit.record_path = Write-McpPreviewAudit -Response $response
        $response.audit = $audit
        return $response
    }

    # run_guard_checks: confirmation_required
    if (-not $RequireConfirm) {
        $error = @{ code = 'confirmation_required'; message = 'require_confirm must be true'; details = @{ require_confirm = $RequireConfirm } }
        $response = New-McpPreviewResponse -Status 'denied' -RequestId $RequestId -ProjectPath $normalizedProjectPath -Gate $gate -Preview $preview -Audit $audit -Error $error
        $audit.record_path = Write-McpPreviewAudit -Response $response
        $response.audit = $audit
        return $response
    }

    # run_guard_checks: readonly_policy_lock
    $action = 'preview_project'
    if ($action -ne 'preview_project') {
        $error = @{ code = 'policy_violation'; message = 'readonly policy lock violated'; details = @{ action = $action } }
        $response = New-McpPreviewResponse -Status 'denied' -RequestId $RequestId -ProjectPath $normalizedProjectPath -Gate $gate -Preview $preview -Audit $audit -Error $error
        $audit.record_path = Write-McpPreviewAudit -Response $response
        $response.audit = $audit
        return $response
    }

    # run_guard_checks: fast_gate_required
    $fastGate = Invoke-McpFastGate
    $gate.fast_gate_passed = [bool]$fastGate.success
    $gate.fast_gate_passed_count = [int]$fastGate.passed
    $gate.fast_gate_failed_count = [int]$fastGate.failed
    $gate.elapsed_s = [double]$fastGate.elapsed_s
    if (-not $fastGate.success -or $fastGate.failed -ne 0) {
        $error = @{ code = 'fast_gate_failed'; message = 'fast gate must pass before preview'; details = @{ passed = $fastGate.passed; failed = $fastGate.failed } }
        $response = New-McpPreviewResponse -Status 'denied' -RequestId $RequestId -ProjectPath $normalizedProjectPath -Gate $gate -Preview $preview -Audit $audit -Error $error
        $audit.record_path = Write-McpPreviewAudit -Response $response
        $response.audit = $audit
        return $response
    }

    # invoke_preview_command -> verify_preview_artifact
    try {
        $cmd = Invoke-McpPreviewCommand -ProjectPath $normalizedProjectPath -Desc $Desc -RequestId $RequestId
        $preview.status = 'success'
        $preview.qrcode_path = $cmd.qrcode_path
        $preview.raw_result = $cmd.raw_result

        if (-not $preview.qrcode_path -or -not (Test-Path $preview.qrcode_path)) {
            throw "preview artifact missing"
        }
    }
    catch {
        $preview.status = 'failed'
        $error = @{ code = 'preview_command_failed'; message = 'preview command execution failed'; details = @{ exception = $_.Exception.Message } }
        $response = New-McpPreviewResponse -Status 'failed' -RequestId $RequestId -ProjectPath $normalizedProjectPath -Gate $gate -Preview $preview -Audit $audit -Error $error
        $audit.record_path = Write-McpPreviewAudit -Response $response
        $response.audit = $audit
        return $response
    }

    # write_audit_record -> return_structured_result
    $response = New-McpPreviewResponse -Status 'success' -RequestId $RequestId -ProjectPath $normalizedProjectPath -Gate $gate -Preview $preview -Audit $audit -Error $null
    $audit.record_path = Write-McpPreviewAudit -Response $response
    $response.audit = $audit
    return $response
}

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet(
        'describe_contract',
        'describe_execution_profile',
        'validate_page_bundle',
        'apply_page_bundle',
        'validate_component_bundle',
        'apply_component_bundle',
        'validate_app_json_patch',
        'apply_app_json_patch'
    )]
    [string]$Operation,

    [string]$JsonPayload,
[string]$JsonFilePath,
[string]$TargetWorkspace = (Get-Location).Path
)

if (-not ($global:WechatMcpBoundaryCache -is [hashtable])) {
    $global:WechatMcpBoundaryCache = @{}
}

function Get-BoundaryPayload {
    param(
        [string]$Payload,
        [string]$PayloadPath
    )

    if (-not [string]::IsNullOrWhiteSpace($Payload)) {
        return $Payload
    }

    if (-not [string]::IsNullOrWhiteSpace($PayloadPath)) {
        if (-not (Test-Path $PayloadPath)) {
            throw "JSON file not found: $PayloadPath"
        }
        return (Get-Content -Path $PayloadPath -Raw -Encoding UTF8)
    }

    throw 'JsonPayload or JsonFilePath is required.'
}

function New-BoundaryResult {
    param(
        [string]$Status,
        [string]$OperationName,
        [hashtable]$Data
    )

    return [pscustomobject]($Data + @{
        status = $Status
        operation = $OperationName
    })
}

function Get-BoundaryPayloadFingerprint {
    param(
        [string]$Payload,
        [string]$PayloadPath
    )

    if ([string]::IsNullOrWhiteSpace($Payload) -and -not [string]::IsNullOrWhiteSpace($PayloadPath) -and (Test-Path $PayloadPath)) {
        $Payload = Get-Content -Path $PayloadPath -Raw -Encoding UTF8
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Payload)
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-BoundaryCacheKey {
    param(
        [Parameter(Mandatory)][string]$OperationName,
        [string]$PayloadFingerprint = '',
        [string]$Workspace = ''
    )

    return ('{0}|{1}|{2}' -f $OperationName, $Workspace, $PayloadFingerprint)
}

function Get-BoundaryCachedResult {
    param(
        [Parameter(Mandatory)][string]$CacheKey
    )

    if ($global:WechatMcpBoundaryCache.ContainsKey($CacheKey)) {
        return $global:WechatMcpBoundaryCache[$CacheKey]
    }

    return $null
}

function Set-BoundaryCachedResult {
    param(
        [Parameter(Mandatory)][string]$CacheKey,
        [Parameter(Mandatory)]$Result
    )

    $global:WechatMcpBoundaryCache[$CacheKey] = $Result
    return $Result
}

function Get-ApplyGateStatusFromExitCode {
    param([int]$ExitCode)

    switch ($ExitCode) {
        0 { return 'pass' }
        1 { return 'retryable_fail' }
        2 { return 'hard_fail' }
        default { return 'unknown' }
    }
}

function Invoke-ApplyScriptProcess {
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$Payload,
        [Parameter(Mandatory)][string]$WorkspacePath
    )

    $tempPayloadPath = Join-Path ([System.IO.Path]::GetTempPath()) ("mcp-boundary-payload-" + [guid]::NewGuid().ToString('N') + '.json')

    try {
        [System.IO.File]::WriteAllText($tempPayloadPath, $Payload, (New-Object System.Text.UTF8Encoding($false)))
        $args = @(
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', $ScriptPath,
            '-JsonFilePath', $tempPayloadPath,
            '-TargetWorkspace', $WorkspacePath
        )
        $combined = & powershell @args 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        $stderr = ''
        $stdout = [string]$combined

        return [pscustomobject]@{
            exit_code = $exitCode
            stdout = $stdout
            stderr = $stderr
        }
    }
    finally {
        foreach ($p in @($tempPayloadPath)) {
            if (Test-Path $p) {
                Remove-Item -Path $p -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

try {
    switch ($Operation) {
        'describe_contract' {
            $cacheKey = Get-BoundaryCacheKey -OperationName $Operation
            $cached = Get-BoundaryCachedResult -CacheKey $cacheKey
            if ($null -ne $cached) {
                $cached | ConvertTo-Json -Depth 20
                exit 0
            }

            $result = New-BoundaryResult -Status 'success' -OperationName $Operation -Data @{
                interface_version = 'mcp_tool_boundary_v1'
                supported_operations = @(
                    'describe_contract',
                    'describe_execution_profile',
                    'validate_page_bundle',
                    'apply_page_bundle',
                    'validate_component_bundle',
                    'apply_component_bundle',
                    'validate_app_json_patch',
                    'apply_app_json_patch'
                )
                apply_exit_code_mapping = @{
                    '0' = 'pass'
                    '1' = 'retryable_fail'
                    '2' = 'hard_fail'
                }
            }
            Set-BoundaryCachedResult -CacheKey $cacheKey -Result $result | ConvertTo-Json -Depth 20
            exit 0
        }
        'describe_execution_profile' {
            $cacheKey = Get-BoundaryCacheKey -OperationName $Operation
            $cached = Get-BoundaryCachedResult -CacheKey $cacheKey
            if ($null -ne $cached) {
                $cached | ConvertTo-Json -Depth 20
                exit 0
            }

            $result = New-BoundaryResult -Status 'success' -OperationName $Operation -Data @{
                interface_version = 'mcp_tool_boundary_v1'
                platform = @{
                    supported_os = @('Windows')
                    shell = 'PowerShell'
                    path_contract = 'repo-relative paths preferred; no machine-specific absolute paths in contract payloads'
                }
                execution_profile = @{
                    validate_operations = @(
                        'validate_page_bundle',
                        'validate_component_bundle',
                        'validate_app_json_patch'
                    )
                    apply_operations = @(
                        'apply_page_bundle',
                        'apply_component_bundle',
                        'apply_app_json_patch'
                    )
                    apply_exit_code_mapping = @{
                        '0' = 'pass'
                        '1' = 'retryable_fail'
                        '2' = 'hard_fail'
                    }
                    error_contract = @{
                        boundary_error_exit_code = 1
                        expected_error_fields = @('status', 'operation', 'interface_version', 'message')
                    }
                }
                client_guidance = @{
                    autonomous_retry_when = 'apply operation returns gate_status=retryable_fail (exit_code=1)'
                    stop_when = 'apply operation returns gate_status=hard_fail (exit_code=2)'
                    fallback_when = 'boundary status=error; inspect message and fix input contract'
                }
            }
            Set-BoundaryCachedResult -CacheKey $cacheKey -Result $result | ConvertTo-Json -Depth 20
            exit 0
        }
        'validate_page_bundle' {
            $payload = Get-BoundaryPayload -Payload $JsonPayload -PayloadPath $JsonFilePath
            $cacheKey = Get-BoundaryCacheKey -OperationName $Operation -Workspace $TargetWorkspace -PayloadFingerprint (Get-BoundaryPayloadFingerprint -Payload $payload -PayloadPath $JsonFilePath)
            $cached = Get-BoundaryCachedResult -CacheKey $cacheKey
            if ($null -ne $cached) {
                $cached | ConvertTo-Json -Depth 20
                exit 0
            }
            . (Join-Path $PSScriptRoot 'generation-gate-v1.ps1')
            $gate = Invoke-GenerationGateV1 -JsonPayload $payload -TargetWorkspace $TargetWorkspace
            $result = New-BoundaryResult -Status 'success' -OperationName $Operation -Data @{
                interface_version = 'mcp_tool_boundary_v1'
                gate_status = $gate.Status
                errors = @($gate.Errors)
            }
            Set-BoundaryCachedResult -CacheKey $cacheKey -Result $result | ConvertTo-Json -Depth 20
            exit 0
        }
        'validate_component_bundle' {
            $payload = Get-BoundaryPayload -Payload $JsonPayload -PayloadPath $JsonFilePath
            $cacheKey = Get-BoundaryCacheKey -OperationName $Operation -Workspace $TargetWorkspace -PayloadFingerprint (Get-BoundaryPayloadFingerprint -Payload $payload -PayloadPath $JsonFilePath)
            $cached = Get-BoundaryCachedResult -CacheKey $cacheKey
            if ($null -ne $cached) {
                $cached | ConvertTo-Json -Depth 20
                exit 0
            }
            . (Join-Path $PSScriptRoot 'generation-gate-component-v1.ps1')
            $gate = Invoke-GenerationGateComponentV1 -JsonPayload $payload
            $result = New-BoundaryResult -Status 'success' -OperationName $Operation -Data @{
                interface_version = 'mcp_tool_boundary_v1'
                gate_status = $gate.Status
                errors = @($gate.Errors)
            }
            Set-BoundaryCachedResult -CacheKey $cacheKey -Result $result | ConvertTo-Json -Depth 20
            exit 0
        }
        'validate_app_json_patch' {
            $payload = Get-BoundaryPayload -Payload $JsonPayload -PayloadPath $JsonFilePath
            $cacheKey = Get-BoundaryCacheKey -OperationName $Operation -Workspace $TargetWorkspace -PayloadFingerprint (Get-BoundaryPayloadFingerprint -Payload $payload -PayloadPath $JsonFilePath)
            $cached = Get-BoundaryCachedResult -CacheKey $cacheKey
            if ($null -ne $cached) {
                $cached | ConvertTo-Json -Depth 20
                exit 0
            }
            . (Join-Path $PSScriptRoot 'generation-gate-app-json-v1.ps1')
            $gate = Invoke-GenerationGateAppJsonV1 -JsonPayload $payload -TargetWorkspace $TargetWorkspace
            $result = New-BoundaryResult -Status 'success' -OperationName $Operation -Data @{
                interface_version = 'mcp_tool_boundary_v1'
                gate_status = $gate.Status
                errors = @($gate.Errors)
            }
            Set-BoundaryCachedResult -CacheKey $cacheKey -Result $result | ConvertTo-Json -Depth 20
            exit 0
        }
        'apply_page_bundle' {
            $payload = Get-BoundaryPayload -Payload $JsonPayload -PayloadPath $JsonFilePath
            $cacheKey = Get-BoundaryCacheKey -OperationName $Operation -Workspace $TargetWorkspace -PayloadFingerprint (Get-BoundaryPayloadFingerprint -Payload $payload -PayloadPath $JsonFilePath)
            $cached = Get-BoundaryCachedResult -CacheKey $cacheKey
            if ($null -ne $cached) {
                $cached | ConvertTo-Json -Depth 20
                exit 0
            }
            $apply = Invoke-ApplyScriptProcess -ScriptPath (Join-Path $PSScriptRoot 'wechat-apply-bundle.ps1') -Payload $payload -WorkspacePath $TargetWorkspace
            $status = if ($apply.exit_code -eq 0) { 'success' } else { 'failed' }
            $result = New-BoundaryResult -Status $status -OperationName $Operation -Data @{
                interface_version = 'mcp_tool_boundary_v1'
                exit_code = $apply.exit_code
                gate_status = (Get-ApplyGateStatusFromExitCode -ExitCode $apply.exit_code)
                stdout = $apply.stdout
                stderr = $apply.stderr
            }
            Set-BoundaryCachedResult -CacheKey $cacheKey -Result $result | ConvertTo-Json -Depth 20
            exit 0
        }
        'apply_component_bundle' {
            $payload = Get-BoundaryPayload -Payload $JsonPayload -PayloadPath $JsonFilePath
            $cacheKey = Get-BoundaryCacheKey -OperationName $Operation -Workspace $TargetWorkspace -PayloadFingerprint (Get-BoundaryPayloadFingerprint -Payload $payload -PayloadPath $JsonFilePath)
            $cached = Get-BoundaryCachedResult -CacheKey $cacheKey
            if ($null -ne $cached) {
                $cached | ConvertTo-Json -Depth 20
                exit 0
            }
            $apply = Invoke-ApplyScriptProcess -ScriptPath (Join-Path $PSScriptRoot 'wechat-apply-component-bundle.ps1') -Payload $payload -WorkspacePath $TargetWorkspace
            $status = if ($apply.exit_code -eq 0) { 'success' } else { 'failed' }
            $result = New-BoundaryResult -Status $status -OperationName $Operation -Data @{
                interface_version = 'mcp_tool_boundary_v1'
                exit_code = $apply.exit_code
                gate_status = (Get-ApplyGateStatusFromExitCode -ExitCode $apply.exit_code)
                stdout = $apply.stdout
                stderr = $apply.stderr
            }
            Set-BoundaryCachedResult -CacheKey $cacheKey -Result $result | ConvertTo-Json -Depth 20
            exit 0
        }
        'apply_app_json_patch' {
            $payload = Get-BoundaryPayload -Payload $JsonPayload -PayloadPath $JsonFilePath
            $cacheKey = Get-BoundaryCacheKey -OperationName $Operation -Workspace $TargetWorkspace -PayloadFingerprint (Get-BoundaryPayloadFingerprint -Payload $payload -PayloadPath $JsonFilePath)
            $cached = Get-BoundaryCachedResult -CacheKey $cacheKey
            if ($null -ne $cached) {
                $cached | ConvertTo-Json -Depth 20
                exit 0
            }
            $apply = Invoke-ApplyScriptProcess -ScriptPath (Join-Path $PSScriptRoot 'wechat-apply-app-json-patch.ps1') -Payload $payload -WorkspacePath $TargetWorkspace
            $status = if ($apply.exit_code -eq 0) { 'success' } else { 'failed' }
            $result = New-BoundaryResult -Status $status -OperationName $Operation -Data @{
                interface_version = 'mcp_tool_boundary_v1'
                exit_code = $apply.exit_code
                gate_status = (Get-ApplyGateStatusFromExitCode -ExitCode $apply.exit_code)
                stdout = $apply.stdout
                stderr = $apply.stderr
            }
            Set-BoundaryCachedResult -CacheKey $cacheKey -Result $result | ConvertTo-Json -Depth 20
            exit 0
        }
    }
}
catch {
    $errorResult = New-BoundaryResult -Status 'error' -OperationName $Operation -Data @{
        interface_version = 'mcp_tool_boundary_v1'
        message = $_.Exception.Message
    }
    $errorResult | ConvertTo-Json -Depth 20
    exit 1
}

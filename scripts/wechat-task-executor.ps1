[CmdletBinding()]
param()

if (-not (Get-Command Invoke-TaskSpecToBundle -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-task-bundle-compiler.ps1"
}

if (-not (Get-Command Invoke-WechatCreate -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-create.ps1"
}

if (-not (Get-Command Invoke-GeneratedProjectPreview -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-generated-project.ps1"
}

if (-not (Get-Command Invoke-AcceptanceChecks -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-acceptance-checks.ps1"
}

if (-not (Get-Command Invoke-AcceptanceRepairLoop -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-acceptance-repair-loop.ps1"
}

if (-not (Get-Command Wait-For-DevtoolsPort -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-env-recovery.ps1"
}

function Write-WechatTaskExecutorJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 20
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $json, $encoding)
}

function ConvertTo-WechatBoundaryPlainValue {
    param(
        [Parameter(Mandatory)]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string] -or $Value -is [char] -or $Value -is [bool] -or
        $Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] -or
        $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64] -or
        $Value -is [single] -or $Value -is [double] -or $Value -is [decimal]) {
        return $Value
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $normalized = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $entry = $Value[$key]
            if ($entry -is [System.Collections.IEnumerable] -and -not ($entry -is [string])) {
                $items = New-Object System.Collections.ArrayList
                foreach ($item in $entry) {
                    [void]$items.Add((ConvertTo-WechatBoundaryPlainValue -Value $item))
                }
                $normalized[[string]$key] = $items
            }
            else {
                $normalized[[string]$key] = ConvertTo-WechatBoundaryPlainValue -Value $entry
            }
        }
        return $normalized
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $normalized = New-Object System.Collections.ArrayList
        foreach ($item in $Value) {
            [void]$normalized.Add((ConvertTo-WechatBoundaryPlainValue -Value ([object]$item)))
        }
        return $normalized
    }

    $properties = $Value.PSObject.Properties | Where-Object { $_.MemberType -in @('NoteProperty', 'Property', 'AliasProperty', 'ScriptProperty') }
    if ($properties.Count -gt 0) {
        $normalized = [ordered]@{}
        foreach ($property in $properties) {
            $entry = $property.Value
            if ($entry -is [System.Collections.IEnumerable] -and -not ($entry -is [string])) {
                $items = New-Object System.Collections.ArrayList
                foreach ($item in $entry) {
                    [void]$items.Add((ConvertTo-WechatBoundaryPlainValue -Value $item))
                }
                $normalized[$property.Name] = $items
            }
            else {
                $normalized[$property.Name] = ConvertTo-WechatBoundaryPlainValue -Value $entry
            }
        }
        return $normalized
    }

    return [string]$Value
}

function ConvertTo-WechatBoundaryJson {
    param(
        [Parameter(Mandatory)]$Value
    )

    return ((ConvertTo-WechatBoundaryPlainValue -Value $Value) | ConvertTo-Json -Depth 100 -Compress)
}

function Get-WechatBoundaryApplyScriptPath {
    param(
        [Parameter(Mandatory)][string]$Operation
    )

    switch ($Operation) {
        'apply_page_bundle' { return (Join-Path $PSScriptRoot 'wechat-apply-bundle.ps1') }
        'apply_component_bundle' { return (Join-Path $PSScriptRoot 'wechat-apply-component-bundle.ps1') }
        'apply_app_json_patch' { return (Join-Path $PSScriptRoot 'wechat-apply-app-json-patch.ps1') }
        default { return $null }
    }
}

function Split-WechatPageBundleByRoot {
    param(
        [Parameter(Mandatory)]$PageBundle
    )

    $groups = [ordered]@{}
    foreach ($file in @($PageBundle.files)) {
        $normalizedPath = ([string]$file.path).Trim().Trim('/') -replace '\\', '/'
        if ($normalizedPath -notmatch '^(pages/[^/]+/[^/.]+)\.(wxml|js|wxss|json)$') {
            throw "Unsupported page bundle path for boundary split: $normalizedPath"
        }

        $basePath = $Matches[1]
        if (-not $groups.Contains($basePath)) {
            $groups[$basePath] = New-Object System.Collections.ArrayList
        }
        [void]$groups[$basePath].Add($file)
    }

    $splitBundles = New-Object System.Collections.ArrayList
    foreach ($basePath in @($groups.Keys)) {
        $segments = $basePath -split '/'
        $pageName = if ($segments.Count -ge 2) { [string]$segments[1] } else { Split-Path $basePath -Leaf }
        [void]$splitBundles.Add([ordered]@{
            page_name = $pageName
            source = if ($PageBundle.PSObject.Properties.Name -contains 'source') { [string]$PageBundle.source } else { 'unknown' }
            asset_kind = 'page_template'
            asset_name = if ($PageBundle.PSObject.Properties.Name -contains 'asset_name') { [string]$PageBundle.asset_name } else { $pageName }
            files = @($groups[$basePath])
        })
    }

    return @($splitBundles)
}

function Invoke-WechatDirectApplyFallback {
    param(
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)]$Payload,
        [Parameter(Mandatory)][string]$TargetWorkspace
    )

    $scriptPath = Get-WechatBoundaryApplyScriptPath -Operation $Operation
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        return $null
    }

    $tempPayloadPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wechat-task-apply-" + [guid]::NewGuid().ToString('N') + '.json')
    try {
        $json = ConvertTo-WechatBoundaryJson -Value $Payload
        [System.IO.File]::WriteAllText($tempPayloadPath, $json, (New-Object System.Text.UTF8Encoding($false)))
        $combined = & powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -JsonFilePath $tempPayloadPath -TargetWorkspace $TargetWorkspace 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
        return [pscustomobject]@{
            interface_version = 'mcp_tool_boundary_v1'
            operation = $Operation
            status = if ($exitCode -eq 0) { 'success' } else { 'failed' }
            exit_code = $exitCode
            gate_status = switch ($exitCode) {
                0 { 'pass' }
                1 { 'retryable_fail' }
                2 { 'hard_fail' }
                default { 'unknown' }
            }
            stdout = [string]$combined
            stderr = ''
        }
    }
    finally {
        if (Test-Path $tempPayloadPath) {
            Remove-Item -LiteralPath $tempPayloadPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Set-WechatTaskExecutionProjectIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectDir,
        [string]$NavigationTitle = '',
        [string]$ProjectName = ''
    )

    $appJsonPath = Join-Path $ProjectDir 'app.json'
    $projectConfigPath = Join-Path $ProjectDir 'project.config.json'

    if (-not (Test-Path $appJsonPath)) {
        throw "Task execution identity update failed: missing app.json at $appJsonPath"
    }
    if (-not (Test-Path $projectConfigPath)) {
        throw "Task execution identity update failed: missing project.config.json at $projectConfigPath"
    }

    $appJson = Get-Content $appJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $appJson.window) {
        $appJson | Add-Member -MemberType NoteProperty -Name 'window' -Value ([ordered]@{})
    }
    if (-not [string]::IsNullOrWhiteSpace($NavigationTitle)) {
        $appJson.window.navigationBarTitleText = $NavigationTitle
    }
    Write-WechatTaskExecutorJson -Path $appJsonPath -Value $appJson

    $projectConfig = Get-Content $projectConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not [string]::IsNullOrWhiteSpace($ProjectName)) {
        $projectConfig.projectname = $ProjectName
    }
    Write-WechatTaskExecutorJson -Path $projectConfigPath -Value $projectConfig

    return [pscustomobject]@{
        status = 'success'
        app_title = [string]$appJson.window.navigationBarTitleText
        project_name = [string]$projectConfig.projectname
    }
}

function Get-WechatTaskExecutionShellPrompt {
    param(
        [Parameter(Mandatory)]$TaskSpec
    )

    switch ([string]$TaskSpec.task_family) {
        'marketing-empty-state' { return 'build a notebook mini program' }
        'product-listing' { return 'build a notebook mini program' }
        default { return 'build a notebook mini program' }
    }
}

function Get-WechatTaskExecutionAppPatchValue {
    param(
        [Parameter(Mandatory)]$AppPatch,
        [Parameter(Mandatory)][string]$Name,
        [string]$Default = ''
    )

    if ($null -eq $AppPatch) {
        return $Default
    }

    if ($AppPatch -is [System.Collections.IDictionary]) {
        if ($AppPatch.Contains($Name) -or @($AppPatch.Keys) -contains $Name) {
            return [string]$AppPatch[$Name]
        }
        return $Default
    }

    $property = $AppPatch.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return [string]$property.Value
    }

    return $Default
}

function Invoke-WechatBoundaryOperation {
    param(
        [Parameter(Mandatory)][string]$Operation,
        [Parameter(Mandatory)]$Payload,
        [Parameter(Mandatory)][string]$TargetWorkspace
    )

    $boundaryScript = Join-Path $PSScriptRoot 'wechat-mcp-tool-boundary.ps1'
    $tempPayloadPath = Join-Path ([System.IO.Path]::GetTempPath()) ("wechat-task-boundary-" + [guid]::NewGuid().ToString('N') + '.json')
    try {
        $json = ConvertTo-WechatBoundaryJson -Value $Payload
        [System.IO.File]::WriteAllText($tempPayloadPath, $json, (New-Object System.Text.UTF8Encoding($false)))
        $result = (& $boundaryScript -Operation $Operation -JsonFilePath $tempPayloadPath -TargetWorkspace $TargetWorkspace | ConvertFrom-Json)
        if ($Operation -like 'apply_*' -and
            [string]$result.status -eq 'failed' -and
            [string]$result.gate_status -eq 'retryable_fail' -and
            ([string]$result.stdout) -match 'Thread failed to start') {
            $fallback = Invoke-WechatDirectApplyFallback -Operation $Operation -Payload $Payload -TargetWorkspace $TargetWorkspace
            if ($null -ne $fallback) {
                return $fallback
            }
        }
        return $result
    }
    finally {
        if (Test-Path $tempPayloadPath) {
            Remove-Item -LiteralPath $tempPayloadPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function New-WechatTaskExecutionRetryReport {
    param(
        [Parameter(Mandatory)][string]$Stage,
        [Parameter(Mandatory)]$BoundaryResult
    )

    return [pscustomobject]@{
        stage = $Stage
        repair_state = 'needs_ai_intervention'
        gate_status = [string]$BoundaryResult.gate_status
        status = [string]$BoundaryResult.status
        errors = @($BoundaryResult.errors)
        stdout = if ($BoundaryResult.PSObject.Properties.Name -contains 'stdout') { [string]$BoundaryResult.stdout } else { '' }
        stderr = if ($BoundaryResult.PSObject.Properties.Name -contains 'stderr') { [string]$BoundaryResult.stderr } else { '' }
    }
}

function Invoke-WechatTaskExecution {
    [CmdletBinding()]
    param(
        $TaskSpec,
        $PageBundle,
        $ComponentBundle,
        $ComponentBundles,
        $AppPatch,
        [string]$OutputDir = '',
        [bool]$Open = $false,
        [bool]$Preview = $false
    )

    if ($null -eq $TaskSpec) {
        throw 'Task execution requires a TaskSpec.'
    }

    Test-WechatTaskSpec -TaskSpec $TaskSpec | Out-Null

    if ($null -eq $PageBundle -or $null -eq $ComponentBundle -or $null -eq $AppPatch) {
        $compiled = Invoke-TaskSpecToBundle -TaskSpec $TaskSpec
        if ($null -eq $PageBundle) { $PageBundle = $compiled.page_bundle }
        if ($null -eq $ComponentBundle) { $ComponentBundle = $compiled.component_bundle }
        if ($null -eq $ComponentBundles) { $ComponentBundles = $compiled.component_bundles }
        if ($null -eq $AppPatch) { $AppPatch = $compiled.app_patch }
    }

    if ($null -eq $ComponentBundles) {
        $ComponentBundles = if ($null -ne $ComponentBundle) { @($ComponentBundle) } else { @() }
    }
    if ($ComponentBundles.Count -eq 0) {
        throw 'Task execution requires at least one component bundle.'
    }

    $create = Invoke-WechatCreate `
        -Prompt (Get-WechatTaskExecutionShellPrompt -TaskSpec $TaskSpec) `
        -OutputDir $OutputDir `
        -Open $false `
        -Preview $false `
        -RunFastGate $false

    if ($create.status -ne 'success') {
        return [pscustomobject]@{
            status = 'failed'
            stage = 'create'
            reason = 'project_shell_create_failed'
            create_result = $create
        }
    }

    $projectDir = [string]$create.project_dir
    $identity = Set-WechatTaskExecutionProjectIdentity `
        -ProjectDir $projectDir `
        -NavigationTitle (Get-WechatTaskExecutionAppPatchValue -AppPatch $TaskSpec.app_patch -Name 'navigationBarTitleText') `
        -ProjectName (Get-WechatTaskExecutionAppPatchValue -AppPatch $TaskSpec.app_patch -Name 'projectname')

    $componentValidateResults = @()
    $componentApplyResults = @()
    foreach ($componentPayload in @($ComponentBundles)) {
        $componentValidate = Invoke-WechatBoundaryOperation -Operation 'validate_component_bundle' -Payload $componentPayload -TargetWorkspace $projectDir
        $componentValidateResults += ,$componentValidate
        if ([string]$componentValidate.gate_status -ne 'pass') {
            return [pscustomobject]@{
                status = if ([string]$componentValidate.gate_status -eq 'retryable_fail') { 'repair_required' } else { 'failed' }
                stage = 'validate_component_bundle'
                project_dir = $projectDir
                project_identity = $identity
                report = New-WechatTaskExecutionRetryReport -Stage 'validate_component_bundle' -BoundaryResult $componentValidate
                component_validate = $componentValidate
                component_validations = @($componentValidateResults)
            }
        }

        $componentApply = Invoke-WechatBoundaryOperation -Operation 'apply_component_bundle' -Payload $componentPayload -TargetWorkspace $projectDir
        $componentApplyResults += ,$componentApply
        if ([string]$componentApply.status -ne 'success') {
            return [pscustomobject]@{
                status = if ([string]$componentApply.gate_status -eq 'retryable_fail') { 'repair_required' } else { 'failed' }
                stage = 'apply_component_bundle'
                project_dir = $projectDir
                project_identity = $identity
                report = New-WechatTaskExecutionRetryReport -Stage 'apply_component_bundle' -BoundaryResult $componentApply
                component_validate = $componentValidate
                component_apply = $componentApply
                component_validations = @($componentValidateResults)
                component_applications = @($componentApplyResults)
            }
        }
    }

    $componentValidate = $componentValidateResults[0]
    $componentApply = $componentApplyResults[0]
    if ([string]$componentValidate.gate_status -ne 'pass') {
        return [pscustomobject]@{
            status = if ([string]$componentValidate.gate_status -eq 'retryable_fail') { 'repair_required' } else { 'failed' }
            stage = 'validate_component_bundle'
            project_dir = $projectDir
            project_identity = $identity
            report = New-WechatTaskExecutionRetryReport -Stage 'validate_component_bundle' -BoundaryResult $componentValidate
            component_validate = $componentValidate
        }
    }

    $pageValidateResults = @()
    $pageApplyResults = @()
    foreach ($pagePayload in @(Split-WechatPageBundleByRoot -PageBundle $PageBundle)) {
        $pageValidate = Invoke-WechatBoundaryOperation -Operation 'validate_page_bundle' -Payload $pagePayload -TargetWorkspace $projectDir
        $pageValidateResults += ,$pageValidate
        if ([string]$pageValidate.gate_status -ne 'pass') {
            return [pscustomobject]@{
                status = if ([string]$pageValidate.gate_status -eq 'retryable_fail') { 'repair_required' } else { 'failed' }
                stage = 'validate_page_bundle'
                project_dir = $projectDir
                project_identity = $identity
                report = New-WechatTaskExecutionRetryReport -Stage 'validate_page_bundle' -BoundaryResult $pageValidate
                component_validate = $componentValidate
                component_apply = $componentApply
                page_validate = $pageValidate
                page_validations = @($pageValidateResults)
            }
        }

        $pageApply = Invoke-WechatBoundaryOperation -Operation 'apply_page_bundle' -Payload $pagePayload -TargetWorkspace $projectDir
        $pageApplyResults += ,$pageApply
        if ([string]$pageApply.status -ne 'success') {
            return [pscustomobject]@{
                status = if ([string]$pageApply.gate_status -eq 'retryable_fail') { 'repair_required' } else { 'failed' }
                stage = 'apply_page_bundle'
                project_dir = $projectDir
                project_identity = $identity
                report = New-WechatTaskExecutionRetryReport -Stage 'apply_page_bundle' -BoundaryResult $pageApply
                component_validate = $componentValidate
                component_apply = $componentApply
                page_validate = $pageValidate
                page_apply = $pageApply
                page_validations = @($pageValidateResults)
                page_applications = @($pageApplyResults)
            }
        }
    }

    $pageValidate = $pageValidateResults[0]
    $pageApply = $pageApplyResults[0]

    $appValidate = Invoke-WechatBoundaryOperation -Operation 'validate_app_json_patch' -Payload $AppPatch -TargetWorkspace $projectDir
    if ([string]$appValidate.gate_status -ne 'pass') {
        return [pscustomobject]@{
            status = if ([string]$appValidate.gate_status -eq 'retryable_fail') { 'repair_required' } else { 'failed' }
            stage = 'validate_app_json_patch'
            project_dir = $projectDir
            project_identity = $identity
            report = New-WechatTaskExecutionRetryReport -Stage 'validate_app_json_patch' -BoundaryResult $appValidate
            component_validate = $componentValidate
            component_apply = $componentApply
            page_validate = $pageValidate
            page_apply = $pageApply
            app_validate = $appValidate
        }
    }

    $appApply = Invoke-WechatBoundaryOperation -Operation 'apply_app_json_patch' -Payload $AppPatch -TargetWorkspace $projectDir
    if ([string]$appApply.status -ne 'success') {
        return [pscustomobject]@{
            status = if ([string]$appApply.gate_status -eq 'retryable_fail') { 'repair_required' } else { 'failed' }
            stage = 'apply_app_json_patch'
            project_dir = $projectDir
            project_identity = $identity
            report = New-WechatTaskExecutionRetryReport -Stage 'apply_app_json_patch' -BoundaryResult $appApply
            component_validate = $componentValidate
            component_apply = $componentApply
            page_validate = $pageValidate
            page_apply = $pageApply
            app_validate = $appValidate
            app_apply = $appApply
        }
    }

    $acceptance = Invoke-AcceptanceChecks -TaskSpec $TaskSpec -ProjectDir $projectDir
    if ([string]$acceptance.status -ne 'pass') {
        $acceptanceRepair = Invoke-AcceptanceRepairLoop -TaskSpec $TaskSpec -ProjectDir $projectDir -Acceptance $acceptance
        if ([string]$acceptanceRepair.status -eq 'pass') {
            $acceptance = $acceptanceRepair.acceptance
        }
        else {
            return [pscustomobject]@{
                status = 'repair_exhausted'
                stage = 'acceptance_checks'
                project_dir = $projectDir
                project_identity = $identity
                report = [pscustomobject]@{
                    stage = 'acceptance_checks'
                    repair_state = 'repair_exhausted'
                    status = [string]$acceptance.status
                    missed_checks = @($acceptance.missed_checks)
                }
                component_validate = $componentValidate
                component_apply = $componentApply
                page_validate = $pageValidate
                page_apply = $pageApply
                app_validate = $appValidate
                app_apply = $appApply
                acceptance = $acceptance
                acceptance_repair_loop = $acceptanceRepair
                component_validations = @($componentValidateResults)
                component_applications = @($componentApplyResults)
            }
        }
    }

    $openResult = [pscustomobject]@{ status = 'skipped' }
    $envRecovery = $null
    if ($Open -or $Preview) {
        $openResult = [pscustomobject](Invoke-GeneratedProjectOpen -ProjectPath $projectDir)
        $envRecovery = Wait-For-DevtoolsPort -RetryCount 5 -DelaySeconds 3
    }

    $previewResult = [pscustomobject]@{ status = 'skipped' }
    if ($Preview) {
        if ($null -ne $envRecovery -and [string]$envRecovery.status -ne 'ready') {
            $previewResult = [pscustomobject]@{
                status = 'blocked'
                reason = 'devtools_open_api_not_ready'
                env_recovery = $envRecovery
            }
        }
        else {
            $previewResult = [pscustomobject](Invoke-GeneratedProjectPreview -ProjectPath $projectDir -RequireConfirm $false)
        }
    }

    return [pscustomobject]@{
        status = 'success'
        stage = 'completed'
        project_dir = $projectDir
        project_identity = $identity
        open_result = $openResult
        env_recovery = $envRecovery
        preview_result = $previewResult
        component_validate = $componentValidate
        component_apply = $componentApply
        component_validations = @($componentValidateResults)
        component_applications = @($componentApplyResults)
        page_validate = $pageValidate
        page_apply = $pageApply
        page_validations = @($pageValidateResults)
        page_applications = @($pageApplyResults)
        app_validate = $appValidate
        app_apply = $appApply
        acceptance = $acceptance
        acceptance_repair_loop = if ($null -ne $acceptanceRepair) { $acceptanceRepair } else { $null }
    }
}

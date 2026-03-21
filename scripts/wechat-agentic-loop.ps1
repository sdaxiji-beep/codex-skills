[CmdletBinding()]
param()

. "$PSScriptRoot\wechat-write-guard.ps1"
. "$PSScriptRoot\wechat-deploy.ps1"
. "$PSScriptRoot\wechat-auto-fix.ps1"
. "$PSScriptRoot\wechat-readonly-flow.ps1"

function Invoke-AgenticValidation {
    param(
        [ValidateSet('auto', 'suite', 'embedded', 'command')]
        [string]$ValidationMode = 'auto',
        [int]$ValidationLayer = 4,
        [string]$ValidationCommand = '',
        [string]$TestSuitePath = "$(Join-Path $PSScriptRoot 'test-wechat-skill.ps1')"
    )

    $mode = $ValidationMode
    if ($mode -eq 'auto') {
        $mode = if ($ValidationLayer -le 1) { 'embedded' } else { 'suite' }
    }

    if ($mode -eq 'embedded') {
        $flow = Invoke-FlowViaAutomator
        if ($null -eq $flow) {
            return @{
                status     = 'needs_fix'
                success    = $false
                passed     = 0
                failed     = 1
                fix_hint   = 'embedded_validation_returned_null_flow'
                page_state = $null
                raw_output = ''
            }
        }

        $source = $flow.page_signature.source
        if ([string]::IsNullOrWhiteSpace($source)) {
            return @{
                status     = 'needs_fix'
                success    = $false
                passed     = 0
                failed     = 1
                fix_hint   = 'page_signature_source_missing'
                page_state = $null
                raw_output = ''
            }
        }

        return @{
            status     = 'success'
            success    = $true
            passed     = 1
            failed     = 0
            fix_hint   = ''
            page_state = $null
            raw_output = ''
        }
    }

    if ($mode -eq 'command') {
        if ([string]::IsNullOrWhiteSpace($ValidationCommand)) {
            return @{
                status     = 'needs_fix'
                success    = $false
                passed     = 0
                failed     = 1
                fix_hint   = 'validation_command_missing'
                page_state = $null
                raw_output = ''
            }
        }

        $commandOutput = & powershell -ExecutionPolicy Bypass -Command $ValidationCommand 2>&1 | Out-String
        $commandSuccess = ($LASTEXITCODE -eq 0)
        return @{
            status     = if ($commandSuccess) { 'success' } else { 'needs_fix' }
            success    = $commandSuccess
            passed     = if ($commandSuccess) { 1 } else { 0 }
            failed     = if ($commandSuccess) { 0 } else { 1 }
            fix_hint   = if ($commandSuccess) { '' } else { 'validation_command_failed' }
            page_state = $null
            raw_output = $commandOutput
        }
    }

    $previousDeployAutoConfirm = $env:DEPLOY_AUTO_CONFIRM
    $previousWriteGuardAutoConfirm = $env:WRITE_GUARD_AUTO_CONFIRM
    try {
        Remove-Item Env:DEPLOY_AUTO_CONFIRM -ErrorAction SilentlyContinue
        Remove-Item Env:WRITE_GUARD_AUTO_CONFIRM -ErrorAction SilentlyContinue
        $output = & powershell -ExecutionPolicy Bypass -File $TestSuitePath -SkipSmoke 2>&1 | Out-String
    }
    finally {
        if ($null -ne $previousDeployAutoConfirm) {
            $env:DEPLOY_AUTO_CONFIRM = $previousDeployAutoConfirm
        }
        else {
            Remove-Item Env:DEPLOY_AUTO_CONFIRM -ErrorAction SilentlyContinue
        }

        if ($null -ne $previousWriteGuardAutoConfirm) {
            $env:WRITE_GUARD_AUTO_CONFIRM = $previousWriteGuardAutoConfirm
        }
        else {
            Remove-Item Env:WRITE_GUARD_AUTO_CONFIRM -ErrorAction SilentlyContinue
        }
    }
    $passed = 0
    $failed = 0
    $success = $false

    if ($output -match '"passed"\s*:\s*(\d+)') { $passed = [int]$Matches[1] }
    if ($output -match '"failed"\s*:\s*(\d+)') { $failed = [int]$Matches[1] }
    if ($output -match '"success"\s*:\s*true') { $success = $true }

    $pageState = $null
    try {
        $probeScript = Join-Path (Split-Path $PSScriptRoot -Parent) 'probe-automator.js'
        $probeRaw = (& node $probeScript 2>$null | Out-String).Trim()
        if ($probeRaw) {
            $pageState = $probeRaw | ConvertFrom-Json -ErrorAction SilentlyContinue
        }
    }
    catch {
    }

    return @{
        status     = if ($success) { 'success' } else { 'needs_fix' }
        success    = $success
        passed     = $passed
        failed     = $failed
        fix_hint   = if ($success) { '' } else { 'validation_failed_requires_fix' }
        page_state = $pageState
        raw_output = $output
    }
}

function Get-AgenticProjectRoot {
    param([string]$TargetFile)

    $resolvedTarget = Resolve-AgenticTargetPath -TargetFile $TargetFile
    if ([string]::IsNullOrWhiteSpace($resolvedTarget)) {
        return $script:SandboxProjectPath
    }

    $candidate = if (Test-Path $resolvedTarget) {
        $targetItem = Get-Item $resolvedTarget
        if ($targetItem -is [System.IO.DirectoryInfo]) {
            $targetItem.FullName
        }
        else {
            Split-Path $targetItem.FullName -Parent
        }
    }
    else {
        Split-Path $resolvedTarget -Parent
    }

    while (-not [string]::IsNullOrWhiteSpace($candidate)) {
        if ((Test-Path (Join-Path $candidate '.git')) -or (Test-Path (Join-Path $candidate 'project.config.json'))) {
            return $candidate
        }

        $parent = Split-Path $candidate -Parent
        if ($parent -eq $candidate) {
            break
        }
        $candidate = $parent
    }

    return $script:SandboxProjectPath
}

function Resolve-AgenticTargetPath {
    param([string]$TargetFile)

    if ([string]::IsNullOrWhiteSpace($TargetFile)) {
        return $TargetFile
    }

    $repoRoot = Split-Path $PSScriptRoot -Parent

    if (-not [System.IO.Path]::IsPathRooted($TargetFile)) {
        return [System.IO.Path]::GetFullPath((Join-Path $repoRoot $TargetFile))
    }

    return $TargetFile
}

function Read-TaskSpec {
    param(
        [Parameter(Mandatory)][string]$SpecPath
    )

    if (-not (Test-Path $SpecPath)) {
        throw "spec file not found: $SpecPath"
    }

    $spec = Get-Content $SpecPath -Raw | ConvertFrom-Json -ErrorAction Stop
    if (-not $spec.task -or [string]::IsNullOrWhiteSpace($spec.task.title)) {
        throw "spec missing task.title: $SpecPath"
    }

    return $spec
}

function Write-AgenticLoopState {
    param(
        [string]$Task,
        [int]$Iteration,
        [int]$MaxIterations,
        [bool]$Validated,
        [datetime]$StartTime
    )

    $statePath = Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\loop-state.json'
    New-Item -ItemType Directory -Force -Path (Split-Path $statePath) | Out-Null
    @{
        task        = $Task
        iteration   = $Iteration
        max         = $MaxIterations
        validated   = $Validated
        start_time  = $StartTime.ToString('o')
        last_update = (Get-Date).ToString('o')
    } | ConvertTo-Json -Depth 5 | Set-Content $statePath -Encoding UTF8

    return $statePath
}

function Write-AgenticTaskRecord {
    param(
        [string]$TaskId,
        [string[]]$TargetFiles,
        [object]$RecordConfig,
        [string]$RecordPath,
        [hashtable]$Report,
        [string]$Task,
        [string]$DeployTarget,
        [string]$DeployName,
        [string]$RollbackMode
    )

    $recordEnabled = $true
    if ($null -ne $RecordConfig -and $null -ne $RecordConfig.enabled) {
        $recordEnabled = [bool]$RecordConfig.enabled
    }
    if (-not $recordEnabled) {
        return $null
    }

    $fields = @()
    if ($null -ne $RecordConfig -and $RecordConfig.fields) {
        $fields = @($RecordConfig.fields)
    }

    $taskKey = if (-not [string]::IsNullOrWhiteSpace($TaskId)) {
        $TaskId
    }
    else {
        (($Task -replace '[^A-Za-z0-9_-]', '-') -replace '-{2,}', '-').Trim('-')
    }
    if ([string]::IsNullOrWhiteSpace($taskKey)) {
        $taskKey = 'task'
    }

    $resolvedPath = $null
    if (-not [string]::IsNullOrWhiteSpace($RecordPath)) {
        $resolvedPath = if ([System.IO.Path]::IsPathRooted($RecordPath)) {
            $RecordPath
        }
        else {
            Join-Path (Split-Path $PSScriptRoot -Parent) $RecordPath
        }
    }
    else {
        $outputDir = if ($null -ne $RecordConfig -and $RecordConfig.output_path) {
            [string]$RecordConfig.output_path
        }
        else {
            Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\records'
        }
        if (-not [System.IO.Path]::IsPathRooted($outputDir)) {
            $outputDir = Join-Path (Split-Path $PSScriptRoot -Parent) $outputDir
        }
        $resolvedPath = Join-Path $outputDir "$taskKey-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    }

    $validationSteps = @($Report.steps | Where-Object { $_.step -eq 'validate' })
    $lastValidation = if ($validationSteps.Count -gt 0) { $validationSteps[-1] } else { $null }
    $deploySteps = @($Report.steps | Where-Object { $_.step -eq 'deploy' })
    $lastDeploy = if ($deploySteps.Count -gt 0) { $deploySteps[-1] } else { $null }
    $rollbackSteps = @($Report.steps | Where-Object { $_.step -eq 'rollback' })

    $fullRecord = [ordered]@{
        task_id       = $taskKey
        title         = $Task
        status        = $Report.status
        elapsed_s     = $Report.elapsed_s
        validated     = if ($lastValidation) { $lastValidation.status } else { $null }
        deployed      = if ($lastDeploy) { $lastDeploy.status } else { $null }
        changes       = @($TargetFiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        timestamp     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        target_file   = if (@($TargetFiles).Count -gt 0) { $TargetFiles[0] } else { $null }
        deploy_target = $DeployTarget
        deploy_name   = $DeployName
        rollback_mode = $RollbackMode
        validation    = if ($lastValidation) {
            @{
                status     = $lastValidation.status
                pass_count = $lastValidation.pass_count
                fail_count = $lastValidation.fail_count
                fix_hint   = $lastValidation.fix_hint
            }
        } else { $null }
        deploy        = if ($lastDeploy) {
            @{
                status = $lastDeploy.status
                target = $lastDeploy.target
            }
        } else { $null }
        rollback      = if ($rollbackSteps.Count -gt 0) {
            @{
                applied = $true
                count   = $rollbackSteps.Count
            }
        } else {
            @{
                applied = $false
                count   = 0
            }
        }
    }

    $record = if ($fields.Count -gt 0) {
        $filtered = [ordered]@{}
        foreach ($field in $fields) {
            if ($fullRecord.Contains($field)) {
                $filtered[$field] = $fullRecord[$field]
            }
        }
        $filtered
    }
    else {
        $fullRecord
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $resolvedPath) | Out-Null
    $record | ConvertTo-Json -Depth 8 | Set-Content $resolvedPath -Encoding UTF8
    return $resolvedPath
}

function Invoke-RollbackByPolicy {
    param(
        [string]$Policy,
        [string]$TargetFile,
        [string]$ProjectPath
    )

    if ([string]::IsNullOrWhiteSpace($Policy)) {
        return @{
            applied = $false
            mode    = 'none'
        }
    }

    switch ($Policy) {
        'restore_target_files' {
            if ([string]::IsNullOrWhiteSpace($TargetFile) -or [string]::IsNullOrWhiteSpace($ProjectPath)) {
                return @{
                    applied = $false
                    mode    = $Policy
                }
            }

            $relative = $TargetFile -replace [regex]::Escape($ProjectPath.TrimEnd('\') + '\'), ''
            $tracked = Invoke-GitProjectCommand -ProjectPath $ProjectPath -GitArguments @('ls-files', '--error-unmatch', $relative)
            if ($tracked.success) {
                Invoke-GitProjectCommand -ProjectPath $ProjectPath -GitArguments @('checkout', 'HEAD', '--', $relative) | Out-Null
            }
            elseif (Test-Path $TargetFile) {
                Remove-Item $TargetFile -Force -ErrorAction SilentlyContinue
            }

            Write-Host "[ROLLBACK] restored: $relative"
            return @{
                applied = $true
                mode    = $Policy
                target  = $relative
            }
        }
        'notify_only' {
            Write-Host '[ROLLBACK] notify_only: manual follow-up required'
            return @{
                applied = $false
                mode    = $Policy
            }
        }
        'abort' {
            Write-Host '[ROLLBACK] abort: stopping without extra rollback action'
            return @{
                applied = $false
                mode    = $Policy
            }
        }
        default {
            return @{
                applied = $false
                mode    = $Policy
            }
        }
    }
}

function Invoke-AgenticLoop {
    param(
        [Parameter(Mandatory)][string]$Task,
        [string]$TargetFile = '',
        [string[]]$TargetFiles = @(),
        [string]$NewContent = '',
        [string[]]$NewContents = @(),
        [ValidateSet('none', 'preview', 'upload', 'list-functions', 'cloud', 'cloud-all', 'cloud-changed')]
        [string]$DeployTarget = 'none',
        [string]$DeployName = '',
        [bool]$AutoMode = $false,
        [bool]$AutoWrite = $false,
        [bool]$AutoDeploy = $false,
        [string]$DeployVersion = '1.0.0',
        [string]$TaskId = '',
        [object]$RecordConfig = $null,
        [string]$RecordPath = '',
        [object]$RollbackConfig = $null,
        [string]$RollbackMode = 'target-file',
        [int]$MaxFixRounds = 3,
        [ValidateSet('auto', 'suite', 'embedded', 'command')]
        [string]$ValidationMode = 'auto',
        [int]$ValidationLayer = 4,
        [string]$ValidationCommand = '',
        [string]$TestSuitePath = "$(Join-Path $PSScriptRoot 'test-wechat-skill.ps1')"
    )

    $startTime = Get-Date
    $resolvedTargetFiles = @()
    if ($TargetFiles -and $TargetFiles.Count -gt 0) {
        $resolvedTargetFiles = @($TargetFiles | ForEach-Object { Resolve-AgenticTargetPath -TargetFile $_ })
    }
    elseif (-not [string]::IsNullOrWhiteSpace($TargetFile)) {
        $resolvedTargetFiles = @(Resolve-AgenticTargetPath -TargetFile $TargetFile)
    }

    $resolvedTargetFile = if ($resolvedTargetFiles.Count -gt 0) { $resolvedTargetFiles[0] } else { '' }
    $effectiveContents = @()
    if ($NewContents -and $NewContents.Count -gt 0) {
        $effectiveContents = @($NewContents)
    }
    elseif (-not [string]::IsNullOrWhiteSpace($NewContent)) {
        $effectiveContents = @($NewContent)
    }

    $effectiveAutoWrite = $AutoMode -or $AutoWrite
    $effectiveAutoDeploy = $AutoMode -or $AutoDeploy
    $writeResult = @{
        status = 'skipped'
    }
    $report = @{
        task       = $Task
        start_time = $startTime.ToString('o')
        steps      = @()
        status     = 'running'
    }

    if ($resolvedTargetFiles.Count -gt 0 -and $effectiveContents.Count -gt 0) {
        if ($resolvedTargetFiles.Count -ne $effectiveContents.Count) {
            throw "TargetFiles/NewContents count mismatch: $($resolvedTargetFiles.Count) vs $($effectiveContents.Count)"
        }

        $projectPath = Get-AgenticProjectRoot -TargetFile $resolvedTargetFile
        $writeResult = Invoke-SafeWrite `
            -ProjectPath $projectPath `
            -Description "agentic: $Task" `
            -FilesToBackup $resolvedTargetFiles `
            -RequireConfirm (-not $effectiveAutoWrite) `
            -WriteAction {
                for ($i = 0; $i -lt $resolvedTargetFiles.Count; $i++) {
                    $targetPath = $resolvedTargetFiles[$i]
                    $content = $effectiveContents[$i]
                    $dir = Split-Path $targetPath -Parent
                    if (-not (Test-Path $dir)) {
                        New-Item -ItemType Directory -Force -Path $dir | Out-Null
                    }
                    Set-Content -Path $targetPath -Value $content -Encoding UTF8
                }
            }

        $report.steps += @{
            step   = 'write'
            status = $writeResult.status
        }

        if ($writeResult.status -ne 'success') {
            $report.status = 'cancelled'
            $report.elapsed_s = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
            Write-AgenticLoopState -Task $Task -Iteration 0 -MaxIterations $MaxFixRounds -Validated $false -StartTime $startTime | Out-Null
            Write-AgenticTaskRecord -TaskId $TaskId -TargetFiles $resolvedTargetFiles -RecordConfig $RecordConfig -RecordPath $RecordPath -Report $report -Task $Task -DeployTarget $DeployTarget -DeployName $DeployName -RollbackMode $RollbackMode | Out-Null
            return $report
        }
    }

    $iteration = 0
    $validated = $false
    while (-not $validated -and $iteration -lt $MaxFixRounds) {
        $iteration++
        Write-Host ""
        Write-Host "[LOOP] iteration $iteration/$MaxFixRounds validation..."

        $validationResult = Invoke-AgenticValidation `
            -ValidationMode $ValidationMode `
            -ValidationLayer $ValidationLayer `
            -ValidationCommand $ValidationCommand `
            -TestSuitePath $TestSuitePath

        $report.steps += @{
            step       = 'validate'
            iteration  = $iteration
            status     = $validationResult.status
            pass_count = $validationResult.passed
            fail_count = $validationResult.failed
            fix_hint   = $validationResult.fix_hint
        }

        if ($validationResult.success) {
            Write-Host "[LOOP] validation passed ($($validationResult.passed) tests)"
            $validated = $true
            break
        }

        $iterReportPath = Join-Path (Split-Path $PSScriptRoot -Parent) "artifacts\loop-iter-$iteration.json"
        New-Item -ItemType Directory -Force -Path (Split-Path $iterReportPath) | Out-Null
        @{
            iteration    = $iteration
            passed       = $false
            pass_count   = $validationResult.passed
            fail_count   = $validationResult.failed
            page_context = $validationResult.page_state
            fix_hint     = "iteration $iteration failed, analyze and repair"
            raw_output   = (($validationResult.raw_output -split "`r?`n") | Select-Object -Last 50)
        } | ConvertTo-Json -Depth 8 | Set-Content $iterReportPath -Encoding UTF8

        Write-AgenticLoopState -Task $Task -Iteration $iteration -MaxIterations $MaxFixRounds -Validated $false -StartTime $startTime | Out-Null
        Write-Host "[LOOP] report: $iterReportPath"

        if (-not $AutoMode) {
            Write-Host '[LOOP] fix the issue, then press Enter to continue (Ctrl+C to stop)'
            Read-Host | Out-Null
        }
        else {
            Start-Sleep -Seconds 3
        }
    }

    Write-AgenticLoopState -Task $Task -Iteration $iteration -MaxIterations $MaxFixRounds -Validated $validated -StartTime $startTime | Out-Null

    if (-not $validated) {
        if (
            ($writeResult.status -eq 'success') -and
            (@($resolvedTargetFiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0)
        ) {
            Write-Host "[LOOP] validation failed, running rollback for target files"
            $projectPath = Get-AgenticProjectRoot -TargetFile $resolvedTargetFile
            $validationFailurePolicy = if ($RollbackConfig -and $RollbackConfig.on_validate_fail) {
                [string]$RollbackConfig.on_validate_fail
            }
            else {
                'restore_target_files'
            }
            $rollbackResult = Invoke-RollbackByPolicy -Policy $validationFailurePolicy -TargetFile $resolvedTargetFile -ProjectPath $projectPath
            $report.steps += @{
                step   = 'rollback'
                target = $resolvedTargetFile
                status = if ($rollbackResult.applied) { 'rolled_back' } else { $rollbackResult.mode }
            }
            $report.status = 'rolled_back'
        }
        else {
            $report.status = 'max_iterations'
        }

        Write-Host "[LOOP] max iterations reached ($MaxFixRounds)"
        $report.end_time = (Get-Date).ToString('o')
        $report.elapsed_s = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)
        Write-AgenticTaskRecord -TaskId $TaskId -TargetFiles @($resolvedTargetFile) -RecordConfig $RecordConfig -RecordPath $RecordPath -Report $report -Task $Task -DeployTarget $DeployTarget -DeployName $DeployName -RollbackMode $RollbackMode | Out-Null
        return $report
    }

    if ($DeployTarget -ne 'none') {
        $deployResult = switch ($DeployTarget) {
            'preview' {
                Invoke-WechatDeploy -Mode 'preview' -RequireConfirm (-not $effectiveAutoDeploy)
            }
            'upload' {
                Invoke-WechatUpload -Version $DeployVersion -RequireConfirm (-not $effectiveAutoDeploy)
            }
            'list-functions' {
                Invoke-WechatDeploy -Mode 'list-functions' -RequireConfirm (-not $effectiveAutoDeploy)
            }
            'cloud' {
                if ([string]::IsNullOrWhiteSpace($DeployName)) {
                    @{
                        status = 'failed'
                        error  = 'cloud mode requires DeployName'
                    }
                }
                else {
                    Invoke-WechatDeploy -Mode 'deploy-function' -FunctionName $DeployName -RequireConfirm (-not $effectiveAutoDeploy)
                }
            }
            'cloud-all' {
                $config = Get-DeployConfig
                $functions = @(Get-CloudFunctions -CloudFunctionRoot $config.cloudFunctionRoot)
                $items = foreach ($func in $functions) {
                    Invoke-WechatDeploy -Mode 'deploy-function' -FunctionName $func -RequireConfirm (-not $effectiveAutoDeploy)
                }
                @{
                    status  = if (@($items | Where-Object { $_.status -eq 'failed' }).Count -gt 0) { 'failed' } else { 'success' }
                    items   = $items
                    targets = $functions
                }
            }
            'cloud-changed' {
                $config = Get-DeployConfig
                $root = $config.cloudFunctionRoot
                $changed = @()
                if (-not [string]::IsNullOrWhiteSpace($root) -and (Test-Path $root)) {
                    $projectPath = Split-Path $root -Parent
                    $gitResult = Invoke-GitProjectCommand -ProjectPath $projectPath -GitArguments @('status', '--short', '--', $root)
                    if ($gitResult.output) {
                        $changed = @($gitResult.output -split "`r?`n" |
                            ForEach-Object { ($_ -split '\s+')[-1] } |
                            ForEach-Object {
                                $relative = $_.Replace($projectPath + '\', '')
                                $parts = $relative -split '[\\/]'
                                if ($parts.Length -ge 2 -and $parts[0] -eq 'cloudfunctions') { $parts[1] }
                            } |
                            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                            Select-Object -Unique)
                    }
                }
                @{
                    status  = 'success'
                    targets = $changed
                    items   = @()
                }
            }
        }

        $report.steps += @{
            step   = 'deploy'
            target = $DeployTarget
            status = $deployResult.status
        }
        if (
            ($deployResult.status -eq 'failed') -and
            ($writeResult.status -eq 'success') -and
            (@($resolvedTargetFiles | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0)
        ) {
            $projectPath = Get-AgenticProjectRoot -TargetFile $resolvedTargetFile
            $deployFailurePolicy = if ($RollbackConfig -and $RollbackConfig.on_deploy_fail) {
                [string]$RollbackConfig.on_deploy_fail
            }
            else {
                'notify_only'
            }
            $deployRollbackResult = Invoke-RollbackByPolicy -Policy $deployFailurePolicy -TargetFile $resolvedTargetFile -ProjectPath $projectPath
            $report.steps += @{
                step   = 'rollback'
                target = $resolvedTargetFile
                status = if ($deployRollbackResult.applied) { 'rolled_back' } else { $deployRollbackResult.mode }
            }
        }
        $report.status = 'done'
    }
    else {
        $report.status = 'validated'
    }

    $report.end_time = (Get-Date).ToString('o')
    $report.elapsed_s = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)

    $logPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\agentic-log.json'
    New-Item -ItemType Directory -Force -Path (Split-Path $logPath) | Out-Null
    $report | ConvertTo-Json -Depth 10 | Set-Content $logPath -Encoding UTF8
    Write-AgenticTaskRecord -TaskId $TaskId -TargetFiles $resolvedTargetFiles -RecordConfig $RecordConfig -RecordPath $RecordPath -Report $report -Task $Task -DeployTarget $DeployTarget -DeployName $DeployName -RollbackMode $RollbackMode | Out-Null

    return $report
}

function Invoke-AgenticLoopFromSpec {
    param(
        [Parameter(Mandatory)][string]$SpecPath,
        [ValidateSet('auto', 'suite', 'embedded', 'command')]
        [string]$ValidationModeOverride = 'auto'
    )

    $spec = Read-TaskSpec -SpecPath $SpecPath
    $taskTitle = [string]$spec.task.title
    $deployType = if ($spec.target -and $spec.target.deploy -and $spec.target.deploy.type) {
        [string]$spec.target.deploy.type
    } else {
        'none'
    }
    $deployName = if ($spec.target -and $spec.target.deploy -and $spec.target.deploy.functions -and $spec.target.deploy.functions.Count -gt 0) {
        [string]$spec.target.deploy.functions[0]
    } else {
        ''
    }
    $deployVersion = if ($spec.target -and $spec.target.deploy -and $spec.target.deploy.version) {
        [string]$spec.target.deploy.version
    }
    else {
        '1.0.0'
    }
    $autoMode = [bool]$spec.auto_mode
    $autoWrite = if ($null -ne $spec.auto_write) { [bool]$spec.auto_write } else { $autoMode }
    $autoDeploy = if ($null -ne $spec.auto_deploy) { [bool]$spec.auto_deploy } else { $autoMode }
    $validationLayer = if ($spec.validation -and $null -ne $spec.validation.layer) { [int]$spec.validation.layer } else { 4 }
    $validationCommand = if ($spec.validation -and $spec.validation.command) {
        [string]$spec.validation.command
    }
    else {
        ''
    }
    $targetFiles = if ($spec.target -and $spec.target.files) { @($spec.target.files) } else { @() }
    $firstTarget = if (@($targetFiles).Count -gt 0) { @($targetFiles)[0] } else { $null }
    $firstFile = if ($null -ne $firstTarget -and $firstTarget.path) {
        [string]($firstTarget.path)
    }
    else {
        ''
    }
    $pathAliases = @{}
    foreach ($alias in $pathAliases.Keys) {
        $firstFile = $firstFile -replace [regex]::Escape($alias), $pathAliases[$alias]
    }
    $resolvedTargetFiles = @()
    foreach ($target in $targetFiles) {
        if ($null -ne $target -and $target.path) {
            $mappedPath = [string]$target.path
            foreach ($alias in $pathAliases.Keys) {
                $mappedPath = $mappedPath -replace [regex]::Escape($alias), $pathAliases[$alias]
            }
            $resolvedTargetFiles += $mappedPath
        }
    }
    if ([string]::IsNullOrWhiteSpace($firstFile)) {
        $firstFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'sandbox\external-project\app.js'
    }
    if (@($resolvedTargetFiles).Count -eq 0) {
        $resolvedTargetFiles = @($firstFile)
    }
    Write-Verbose "[SPEC] mapped target file: $firstFile"
    $description = if ($spec.requirements -and $spec.requirements.description) {
        [string]$spec.requirements.description
    }
    else {
        ''
    }
    $acceptance = if ($spec.requirements -and $spec.requirements.acceptance) {
        @($spec.requirements.acceptance) -join '; '
    }
    else {
        ''
    }
    $constraints = if ($spec.requirements -and $spec.requirements.constraints) {
        @($spec.requirements.constraints) -join '; '
    }
    else {
        ''
    }
    $newContent = if ($spec.target -and $null -ne $spec.target.new_content) {
        [string]($spec.target.new_content)
    }
    else {
        ''
    }
    $newContents = if ($spec.target -and $null -ne $spec.target.new_contents) {
        @($spec.target.new_contents | ForEach-Object { [string]$_ })
    }
    elseif (-not [string]::IsNullOrWhiteSpace($newContent)) {
        @($newContent)
    }
    else {
        @()
    }
    $recordPath = if ($spec.record -and $spec.record.path) {
        [string]($spec.record.path)
    }
    else {
        ''
    }
    $recordConfig = if ($spec.record) { $spec.record } else { $null }
    $rollbackConfig = if ($spec.rollback) { $spec.rollback } else { $null }
    $rollbackMode = if ($spec.rollback -and $spec.rollback.mode) {
        [string]$spec.rollback.mode
    }
    else {
        'target-file'
    }

    Write-Host "[SPEC] title: $taskTitle"
    Write-Host "[SPEC] target file: $firstFile"
    Write-Host "[SPEC] description: $description"
    Write-Host "[SPEC] acceptance: $acceptance"
    Write-Host "[SPEC] constraints: $constraints"
    Write-Host "[SPEC] deploy.type: $deployType"
    Write-Host "[SPEC] auto_mode: $autoMode"
    Write-Host "[SPEC] validation layer: $validationLayer"
    Write-Host "[SPEC] validation command: $validationCommand"
    Write-Host "[SPEC] record.path: $recordPath"
    Write-Host "[SPEC] rollback.mode: $rollbackMode"
    if (-not $newContent) {
        Write-Host '[SPEC] no new_content in spec; caller must provide generated content if write is required'
    }

    $effectiveValidationMode = $ValidationModeOverride
    if ($effectiveValidationMode -eq 'auto' -and -not [string]::IsNullOrWhiteSpace($validationCommand)) {
        $effectiveValidationMode = 'command'
    }

    return Invoke-AgenticLoop `
        -Task $taskTitle `
        -TargetFile $firstFile `
        -TargetFiles $resolvedTargetFiles `
        -NewContent $newContent `
        -NewContents $newContents `
        -DeployTarget $deployType `
        -DeployName $deployName `
        -DeployVersion $deployVersion `
        -TaskId ([string]$spec.task.id) `
        -RecordConfig $recordConfig `
        -RecordPath $recordPath `
        -RollbackConfig $rollbackConfig `
        -RollbackMode $rollbackMode `
        -AutoMode $autoMode `
        -AutoWrite $autoWrite `
        -AutoDeploy $autoDeploy `
        -ValidationMode $effectiveValidationMode `
        -ValidationLayer $validationLayer `
        -ValidationCommand $validationCommand
}

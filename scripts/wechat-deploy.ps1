[CmdletBinding()]
param()

. "$PSScriptRoot\wechat-write-guard.ps1"
. "$PSScriptRoot\wechat-get-port.ps1"
. "$PSScriptRoot\wechat-release-setup.ps1"

function Get-DeployConfig {
    param(
        [string]$ConfigPath = "$(Join-Path (Split-Path $PSScriptRoot -Parent) 'deploy-config.json')"
    )

    return Get-EffectiveDeployConfig -ConfigPath $ConfigPath -WorkspaceRoot (Split-Path $PSScriptRoot -Parent)
}

function Get-CloudFunctions {
    param(
        [string]$CloudFunctionRoot
    )

    if (-not (Test-Path $CloudFunctionRoot)) {
        return @()
    }

    return @(Get-ChildItem $CloudFunctionRoot -Directory | Select-Object -ExpandProperty Name)
}

function Get-WechatCliPath {
    $cliPath = 'C:\Program Files (x86)\Tencent\微信web开发者工具\cli.bat'
    if (-not (Test-Path $cliPath)) {
        throw "cli not found: $cliPath"
    }
    return $cliPath
}

function Invoke-WechatCliCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $cliPath = Get-WechatCliPath
    $raw = (& $cliPath @Arguments 2>&1 | Out-String).Trim()
    $parsed = $null
    try {
        $parsed = $raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
    }

    return @{
        raw       = $raw
        parsed    = $parsed
        exit_code = $LASTEXITCODE
        success   = ($LASTEXITCODE -eq 0)
    }
}

function Get-CloudFunctionList {
    param(
        [string]$ConfigPath = "$(Join-Path (Split-Path $PSScriptRoot -Parent) 'deploy-config.json')"
    )

    $config = Get-DeployConfig -ConfigPath $ConfigPath
    if (-not (Test-Path $config.cloudFunctionRoot)) {
        return @()
    }

    return @(Get-ChildItem $config.cloudFunctionRoot -Directory | ForEach-Object {
        [pscustomobject]@{
            name             = $_.Name
            has_index        = Test-Path (Join-Path $_.FullName 'index.js')
            has_package_json = Test-Path (Join-Path $_.FullName 'package.json')
            path             = $_.FullName
        }
    })
}

function Confirm-DeployAction {
    param(
        [string]$Description,
        [bool]$RequireConfirm = $true
    )

    if (-not $RequireConfirm) {
        return $true
    }

    Write-Host '=== Pending deploy action ==='
    Write-Host $Description
    Write-Host '============================='
    Write-Host 'Type yes to continue. Any other input cancels.'
    $confirm = if ($env:DEPLOY_AUTO_CONFIRM) {
        $env:DEPLOY_AUTO_CONFIRM
    }
    elseif ($env:WRITE_GUARD_AUTO_CONFIRM) {
        $env:WRITE_GUARD_AUTO_CONFIRM
    }
    elseif ([Environment]::UserInteractive) {
        Read-Host
    }
    else {
        Write-Host '[DEPLOY] Non-interactive terminal detected. Set: $env:DEPLOY_AUTO_CONFIRM = ''yes'''
        'no'
    }
    return $confirm -eq 'yes'
}

function Invoke-NodeJsonCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [string[]]$Arguments = @()
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'node'
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $allArgs = @($ScriptPath) + $Arguments
    $psi.Arguments = (($allArgs | ForEach-Object {
                $value = [string]$_
                '"' + ($value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
            }) -join ' ')

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    $stdout = $proc.StandardOutput.ReadToEnd()
    [void]$proc.WaitForExit(180000)
    $stderr = if ($null -ne $stderrTask) { $stderrTask.Result } else { '' }

    if (-not [string]::IsNullOrWhiteSpace($stderr)) {
        $stderr -split "`n" |
            Where-Object { $_.Trim() } |
            ForEach-Object { Write-Verbose "[DEPLOY] $($_.Trim())" }
    }

    $stdout = if ($null -ne $stdout) { $stdout.Trim() } else { '' }
    $parsed = $null
    try {
        $parsed = $stdout | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
    }

    return @{
        raw       = $stdout
        parsed    = $parsed
        stderr    = if ($null -ne $stderr) { $stderr.Trim() } else { '' }
        exit_code = $proc.ExitCode
        success   = ($proc.ExitCode -eq 0)
    }
}

function Invoke-WechatDeploy {
    [CmdletBinding()]
    param(
        [ValidateSet('preview', 'list-functions', 'deploy-function')]
        [string]$Mode = 'preview',
        [string]$FunctionName,
        [bool]$RequireConfirm = $true,
        [string]$ConfigPath = "$(Join-Path (Split-Path $PSScriptRoot -Parent) 'deploy-config.json')"
    )

    $config = Get-DeployConfig -ConfigPath $ConfigPath
    $description = "mode=$Mode cloudEnv=$($config.cloudEnv)"
    if ($FunctionName) { $description += " function=$FunctionName" }
    if (-not (Confirm-DeployAction -Description $description -RequireConfirm $RequireConfirm)) {
        return @{
            status = 'cancelled'
            mode = $Mode
            cloudEnv = $config.cloudEnv
        }
    }

    $scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'wechat-deploy.js'
    $args = @($Mode, $ConfigPath)
    if ($FunctionName) { $args += $FunctionName }
    $detectedPort = Get-WechatDevtoolsPort
    Write-Verbose "[DEPLOY] current port: $detectedPort"
    $prevInjectedPort = $env:DEVTOOLS_PORT
    $env:DEVTOOLS_PORT = [string]$detectedPort
    try {
        $result = Invoke-NodeJsonCommand -ScriptPath $scriptPath -Arguments $args
    }
    finally {
        if ($null -ne $prevInjectedPort) {
            $env:DEVTOOLS_PORT = $prevInjectedPort
        }
        else {
            Remove-Item Env:DEVTOOLS_PORT -ErrorAction SilentlyContinue
        }
    }
    $parsed = $result.parsed
    $normalizedStatus = if ($result.success) { 'success' } else { 'failed' }
    if ($parsed -and $parsed.status) {
        switch ([string]$parsed.status) {
            'preview_ok' { $normalizedStatus = 'success' }
            'deployed' { $normalizedStatus = 'success' }
            'success' { $normalizedStatus = 'success' }
            'preview_failed' { $normalizedStatus = 'failed' }
            'deploy_failed' { $normalizedStatus = 'failed' }
            'preflight_failed' { $normalizedStatus = 'failed' }
            default { }
        }
    }
    $errorInfo = @()
    if ($parsed -and $parsed.errors) {
        $errorInfo += @($parsed.errors | ForEach-Object { [string]$_ })
    }
    if ($parsed -and $parsed.error) {
        $errorInfo += [string]$parsed.error
    }
    if (-not $result.success -and [string]::IsNullOrWhiteSpace(($errorInfo -join ''))) {
        if (-not [string]::IsNullOrWhiteSpace($result.stderr)) {
            $errorInfo += $result.stderr
        }
        elseif (-not [string]::IsNullOrWhiteSpace($result.raw)) {
            $errorInfo += $result.raw
        }
    }

    return @{
        status = $normalizedStatus
        success = ($normalizedStatus -eq 'success')
        mode = $Mode
        cloudEnv = $config.cloudEnv
        functionName = $FunctionName
        output = if ($parsed) { $parsed } else { $result.raw }
        raw_output = $result.raw
        stderr = $result.stderr
        underlying_status = if ($parsed -and $parsed.status) { [string]$parsed.status } else { '' }
        verified = if ($parsed -and $null -ne $parsed.verified) { [bool]$parsed.verified } else { $false }
        port = if ($parsed -and $parsed.port) { $parsed.port } else { $detectedPort }
        errors = @($errorInfo | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        exit_code = $result.exit_code
    }
}

function Invoke-DeployCloudFunction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FuncName,
        [bool]$RequireConfirm = $true,
        [string]$ConfigPath = "$(Join-Path (Split-Path $PSScriptRoot -Parent) 'deploy-config.json')"
    )

    return Invoke-WechatDeploy -Mode 'deploy-function' -FunctionName $FuncName -RequireConfirm $RequireConfirm -ConfigPath $ConfigPath
}

function Invoke-DeployAllCloudFunctions {
    [CmdletBinding()]
    param(
        [bool]$RequireConfirm = $true,
        [string]$ConfigPath = "$(Join-Path (Split-Path $PSScriptRoot -Parent) 'deploy-config.json')"
    )

    $items = @()
    foreach ($func in (Get-CloudFunctionList -ConfigPath $ConfigPath)) {
        $items += Invoke-DeployCloudFunction -FuncName $func.name -RequireConfirm $RequireConfirm -ConfigPath $ConfigPath
    }

    return @{
        status = if (@($items | Where-Object { $_.status -eq 'failed' }).Count -gt 0) { 'failed' } else { 'all_ok' }
        items  = $items
    }
}

function Invoke-DeployChangedCloudFunctions {
    [CmdletBinding()]
    param(
        [bool]$RequireConfirm = $true,
        [string]$ConfigPath = "$(Join-Path (Split-Path $PSScriptRoot -Parent) 'deploy-config.json')"
    )

    $config = Get-DeployConfig -ConfigPath $ConfigPath
    $root = $config.cloudFunctionRoot
    $changed = @()
    if (Test-Path $root) {
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

    $items = @()
    foreach ($funcName in $changed) {
        $items += Invoke-DeployCloudFunction -FuncName $funcName -RequireConfirm $RequireConfirm -ConfigPath $ConfigPath
    }

    return @{
        status  = 'changed_done'
        targets = $changed
        items   = $items
    }
}

function Invoke-WechatPreview {
    [CmdletBinding()]
    param(
        [string]$Desc = '',
        [bool]$RequireConfirm = $true,
        [string]$ConfigPath = "$(Join-Path (Split-Path $PSScriptRoot -Parent) 'deploy-config.json')"
    )

    return Invoke-WechatDeploy -Mode 'preview' -RequireConfirm $RequireConfirm -ConfigPath $ConfigPath
}

function Invoke-WechatUpload {
    [CmdletBinding()]
    param(
        [string]$Version = '1.0.0',
        [string]$Desc = '',
        [bool]$RequireConfirm = $true,
        [string]$ConfigPath = "$(Join-Path (Split-Path $PSScriptRoot -Parent) 'deploy-config.json')"
    )

    $requirement = Resolve-WechatReleaseSetupRequirement -ActionName 'upload' -AllowInteractiveSetup $RequireConfirm -ConfigPath $ConfigPath -WorkspaceRoot (Split-Path $PSScriptRoot -Parent)
    if ($requirement.status -ne 'ready') {
        return @{
            status    = 'needs_release_setup'
            mode      = 'upload'
            readiness = $requirement.readiness
        }
    }

    $config = $requirement.config
    $description = "mode=upload version=$Version cloudEnv=$($config.cloudEnv)"
    if ($Desc) { $description += " desc=$Desc" }
    if (-not (Confirm-DeployAction -Description $description -RequireConfirm $RequireConfirm)) {
        return @{
            status = 'cancelled'
            mode   = 'upload'
        }
    }

    $args = @(
        'upload',
        '--project', (Resolve-Path (Split-Path $config.projectPath -Parent)).Path,
        '--port', [string]$config.devtoolsPort
    )
    if ($Version) { $args += @('--robot', '1') }

    $result = Invoke-WechatCliCommand -Arguments $args
    return @{
        status    = if ($result.success) { 'upload_ok' } else { 'upload_failed' }
        mode      = 'upload'
        version   = $Version
        output    = if ($result.parsed) { $result.parsed } else { $result.raw }
        exit_code = $result.exit_code
    }
}

function Invoke-PackNpm {
    [CmdletBinding()]
    param(
        [bool]$RequireConfirm = $false,
        [string]$ConfigPath = "$(Join-Path (Split-Path $PSScriptRoot -Parent) 'deploy-config.json')"
    )

    $config = Get-DeployConfig -ConfigPath $ConfigPath
    if (-not (Confirm-DeployAction -Description 'build-npm' -RequireConfirm $RequireConfirm)) {
        return @{
            status = 'cancelled'
            mode   = 'build-npm'
        }
    }

    $args = @(
        'build-npm',
        '--project', (Resolve-Path (Split-Path $config.projectPath -Parent)).Path,
        '--port', [string]$config.devtoolsPort
    )
    $result = Invoke-WechatCliCommand -Arguments $args
    return @{
        status    = if ($result.success) { 'buildnpm_ok' } else { 'buildnpm_failed' }
        mode      = 'build-npm'
        output    = if ($result.parsed) { $result.parsed } else { $result.raw }
        exit_code = $result.exit_code
    }
}

function Get-CloudEnvList {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = "$(Join-Path (Split-Path $PSScriptRoot -Parent) 'deploy-config.json')"
    )

    $config = Get-DeployConfig -ConfigPath $ConfigPath
    $args = @(
        'cloud', 'env', 'list',
        '--project', (Resolve-Path (Split-Path $config.projectPath -Parent)).Path,
        '--port', [string]$config.devtoolsPort
    )
    $result = Invoke-WechatCliCommand -Arguments $args
    return @{
        status    = if ($result.success) { 'env_list_ok' } else { 'env_list_failed' }
        cloudEnv  = $config.cloudEnv
        output    = if ($result.parsed) { $result.parsed } else { $result.raw }
        exit_code = $result.exit_code
    }
}

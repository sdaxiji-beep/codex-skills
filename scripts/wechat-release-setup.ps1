[CmdletBinding()]
param()

function Get-ReleaseWorkspaceRoot {
    param(
        [string]$ScriptRoot = $PSScriptRoot
    )

    return (Split-Path $ScriptRoot -Parent)
}

function Get-LocalReleaseConfigPath {
    [CmdletBinding()]
    param(
        [string]$WorkspaceRoot = (Get-ReleaseWorkspaceRoot)
    )

    return (Join-Path $WorkspaceRoot 'config\local-release.config.json')
}

function Get-LocalReleaseConfig {
    [CmdletBinding()]
    param(
        [string]$WorkspaceRoot = (Get-ReleaseWorkspaceRoot)
    )

    $path = Get-LocalReleaseConfigPath -WorkspaceRoot $WorkspaceRoot
    if (-not (Test-Path $path)) {
        return $null
    }

    return (Get-Content $path -Raw | ConvertFrom-Json)
}

function Merge-ConfigObjects {
    param(
        $Base,
        $Overlay
    )

    $merged = [ordered]@{}
    if ($Base) {
        foreach ($prop in $Base.PSObject.Properties) {
            $merged[$prop.Name] = $prop.Value
        }
    }
    if ($Overlay) {
        foreach ($prop in $Overlay.PSObject.Properties) {
            if ($null -ne $prop.Value -and -not [string]::IsNullOrWhiteSpace([string]$prop.Value)) {
                $merged[$prop.Name] = $prop.Value
            }
        }
    }

    return [pscustomobject]$merged
}

function Get-EffectiveDeployConfig {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = (Join-Path (Get-ReleaseWorkspaceRoot) 'deploy-config.json'),
        [string]$WorkspaceRoot = (Get-ReleaseWorkspaceRoot)
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "deploy config not found: $ConfigPath"
    }

    $base = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $local = Get-LocalReleaseConfig -WorkspaceRoot $WorkspaceRoot
    return (Merge-ConfigObjects -Base $base -Overlay $local)
}

function Get-WechatReleaseReadiness {
    [CmdletBinding()]
    param(
        [string]$ConfigPath = (Join-Path (Get-ReleaseWorkspaceRoot) 'deploy-config.json'),
        [string]$WorkspaceRoot = (Get-ReleaseWorkspaceRoot)
    )

    $config = Get-EffectiveDeployConfig -ConfigPath $ConfigPath -WorkspaceRoot $WorkspaceRoot
    $localPath = Get-LocalReleaseConfigPath -WorkspaceRoot $WorkspaceRoot
    $appid = [string]$config.appid
    $privateKeyPath = [string]$config.privateKeyPath
    $projectPath = [string]$config.projectPath
    $projectRoot = [string]$config.projectRoot
    $cloudFunctionRoot = [string]$config.cloudFunctionRoot

    $appidOk = (-not [string]::IsNullOrWhiteSpace($appid)) -and
        (-not [string]::Equals($appid, 'touristappid', [System.StringComparison]::OrdinalIgnoreCase))
    $privateKeyExists = (-not [string]::IsNullOrWhiteSpace($privateKeyPath)) -and (Test-Path $privateKeyPath)
    $projectPathExists = (-not [string]::IsNullOrWhiteSpace($projectPath)) -and (Test-Path $projectPath)
    $projectRootExists = [string]::IsNullOrWhiteSpace($projectRoot) -or (Test-Path $projectRoot)
    $cloudFunctionRootExists = [string]::IsNullOrWhiteSpace($cloudFunctionRoot) -or (Test-Path $cloudFunctionRoot)
    $localConfigExists = Test-Path $localPath

    $fullyReady = $localConfigExists -and $appidOk -and $privateKeyExists -and $projectPathExists -and $projectRootExists -and $cloudFunctionRootExists

    return [pscustomobject]@{
        status                 = if ($fullyReady) { 'ready' } else { 'needs_release_setup' }
        ready                  = $fullyReady
        local_config_exists    = $localConfigExists
        local_config_path      = $localPath
        appid                  = $appid
        appid_ok               = $appidOk
        private_key_path       = $privateKeyPath
        private_key_exists     = $privateKeyExists
        project_path           = $projectPath
        project_path_exists    = $projectPathExists
        project_root           = $projectRoot
        project_root_exists    = $projectRootExists
        cloud_function_root    = $cloudFunctionRoot
        cloud_function_exists  = $cloudFunctionRootExists
        cloud_env              = [string]$config.cloudEnv
        config                 = $config
    }
}

function Invoke-WechatReleaseSetup {
    [CmdletBinding()]
    param(
        [string]$WorkspaceRoot = (Get-ReleaseWorkspaceRoot),
        [string]$ConfigPath = (Join-Path (Get-ReleaseWorkspaceRoot) 'deploy-config.json'),
        [string]$AppId,
        [string]$PrivateKeyPath,
        [string]$ProjectPath,
        [string]$ProjectRoot,
        [string]$CloudFunctionRoot,
        [string]$CloudEnv,
        [string]$DevtoolsPort,
        [switch]$NonInteractive
    )

    $baseConfig = $null
    if (Test-Path $ConfigPath) {
        $baseConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    }
    $existing = Get-LocalReleaseConfig -WorkspaceRoot $WorkspaceRoot

    if ([string]::IsNullOrWhiteSpace($AppId)) { $AppId = [string]$(if ($existing) { $existing.appid } elseif ($baseConfig) { $baseConfig.appid } else { '' }) }
    if ([string]::IsNullOrWhiteSpace($PrivateKeyPath)) { $PrivateKeyPath = [string]$(if ($existing) { $existing.privateKeyPath } elseif ($baseConfig) { $baseConfig.privateKeyPath } else { '' }) }
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) { $ProjectPath = [string]$(if ($existing) { $existing.projectPath } elseif ($baseConfig) { $baseConfig.projectPath } else { '' }) }
    if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = [string]$(if ($existing) { $existing.projectRoot } elseif ($baseConfig) { $baseConfig.projectRoot } else { '' }) }
    if ([string]::IsNullOrWhiteSpace($CloudFunctionRoot)) { $CloudFunctionRoot = [string]$(if ($existing) { $existing.cloudFunctionRoot } elseif ($baseConfig) { $baseConfig.cloudFunctionRoot } else { '' }) }
    if ([string]::IsNullOrWhiteSpace($CloudEnv)) { $CloudEnv = [string]$(if ($existing) { $existing.cloudEnv } elseif ($baseConfig) { $baseConfig.cloudEnv } else { '' }) }
    if ([string]::IsNullOrWhiteSpace($DevtoolsPort)) { $DevtoolsPort = [string]$(if ($existing) { $existing.devtoolsPort } elseif ($baseConfig) { $baseConfig.devtoolsPort } else { 'auto' }) }

    $canPrompt = (-not $NonInteractive) -and [Environment]::UserInteractive
    if ($canPrompt) {
        if ([string]::IsNullOrWhiteSpace($AppId)) { $AppId = Read-Host 'Real appid' }
        if ([string]::IsNullOrWhiteSpace($PrivateKeyPath)) { $PrivateKeyPath = Read-Host 'Private key path' }
        if ([string]::IsNullOrWhiteSpace($ProjectPath)) { $ProjectPath = Read-Host 'Mini program project path' }
        if ([string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot = Read-Host 'Project root (optional if project path is enough)' }
        if ([string]::IsNullOrWhiteSpace($CloudFunctionRoot)) { $CloudFunctionRoot = Read-Host 'Cloud function root (optional)' }
        if ([string]::IsNullOrWhiteSpace($CloudEnv)) { $CloudEnv = Read-Host 'Cloud env (optional)' }
    }

    if ([string]::IsNullOrWhiteSpace($ProjectRoot) -and -not [string]::IsNullOrWhiteSpace($ProjectPath)) {
        $ProjectRoot = Split-Path $ProjectPath -Parent
    }
    if ([string]::IsNullOrWhiteSpace($CloudFunctionRoot) -and -not [string]::IsNullOrWhiteSpace($ProjectRoot)) {
        $candidateCloudRoot = Join-Path $ProjectRoot 'cloudfunctions'
        if (Test-Path $candidateCloudRoot) {
            $CloudFunctionRoot = $candidateCloudRoot
        }
    }

    $errors = @()
    if ([string]::IsNullOrWhiteSpace($AppId) -or [string]::Equals($AppId, 'touristappid', [System.StringComparison]::OrdinalIgnoreCase)) {
        $errors += 'valid_appid_required'
    }
    if ([string]::IsNullOrWhiteSpace($PrivateKeyPath) -or -not (Test-Path $PrivateKeyPath)) {
        $errors += 'private_key_path_invalid'
    }
    if ([string]::IsNullOrWhiteSpace($ProjectPath) -or -not (Test-Path $ProjectPath)) {
        $errors += 'project_path_invalid'
    }

    if ($errors.Count -gt 0) {
        return @{
            status            = 'failed'
            reason            = 'invalid_release_setup_input'
            errors            = $errors
            local_config_path = (Get-LocalReleaseConfigPath -WorkspaceRoot $WorkspaceRoot)
        }
    }

    $configDir = Join-Path $WorkspaceRoot 'config'
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    $localPath = Get-LocalReleaseConfigPath -WorkspaceRoot $WorkspaceRoot

    $localConfig = [ordered]@{
        appid             = $AppId
        privateKeyPath    = $PrivateKeyPath
        projectPath       = $ProjectPath
        projectRoot       = $ProjectRoot
        cloudFunctionRoot = $CloudFunctionRoot
        cloudEnv          = $CloudEnv
        devtoolsPort      = if ([string]::IsNullOrWhiteSpace($DevtoolsPort)) { 'auto' } else { $DevtoolsPort }
        updatedAt         = (Get-Date).ToString('s')
    }

    ([pscustomobject]$localConfig | ConvertTo-Json -Depth 10) | Set-Content -Path $localPath -Encoding UTF8
    $readiness = Get-WechatReleaseReadiness -ConfigPath $ConfigPath -WorkspaceRoot $WorkspaceRoot

    return @{
        status            = if ($readiness.ready) { 'success' } else { 'failed' }
        local_config_path = $localPath
        readiness         = $readiness
    }
}

function Resolve-WechatReleaseSetupRequirement {
    [CmdletBinding()]
    param(
        [string]$ActionName = 'release',
        [bool]$AllowInteractiveSetup = $true,
        [string]$ConfigPath = (Join-Path (Get-ReleaseWorkspaceRoot) 'deploy-config.json'),
        [string]$WorkspaceRoot = (Get-ReleaseWorkspaceRoot)
    )

    $readiness = Get-WechatReleaseReadiness -ConfigPath $ConfigPath -WorkspaceRoot $WorkspaceRoot
    if ($readiness.ready) {
        return @{
            status    = 'ready'
            readiness = $readiness
            config    = $readiness.config
        }
    }

    $canPrompt = $AllowInteractiveSetup -and [Environment]::UserInteractive
    if ($canPrompt) {
        Write-Host "[RELEASE] $ActionName requires local real-deploy setup."
        $setup = Invoke-WechatReleaseSetup -WorkspaceRoot $WorkspaceRoot -ConfigPath $ConfigPath
        $after = Get-WechatReleaseReadiness -ConfigPath $ConfigPath -WorkspaceRoot $WorkspaceRoot
        if ($after.ready) {
            return @{
                status    = 'ready'
                readiness = $after
                config    = $after.config
                setup     = $setup
            }
        }

        return @{
            status    = 'needs_release_setup'
            readiness = $after
            setup     = $setup
        }
    }

    return @{
        status    = 'needs_release_setup'
        readiness = $readiness
    }
}

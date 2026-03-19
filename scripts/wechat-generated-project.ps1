[CmdletBinding()]
param()

. "$PSScriptRoot\wechat-get-port.ps1"
. "$PSScriptRoot\wechat-open-project.ps1"
. "$PSScriptRoot\wechat-deploy.ps1"
. "$PSScriptRoot\wechat-release-setup.ps1"

function Get-GeneratedProjectRoot {
    return (Join-Path (Split-Path $PSScriptRoot -Parent) 'generated')
}

function Get-GeneratedProjectList {
    param(
        [string]$Root = ''
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Get-GeneratedProjectRoot
    }

    if (-not (Test-Path $Root)) {
        return @()
    }

    return @(Get-ChildItem $Root -Directory |
        Sort-Object LastWriteTime -Descending |
        ForEach-Object {
            [pscustomobject]@{
                name           = $_.Name
                project_dir    = $_.FullName
                last_write_time = $_.LastWriteTime
            }
        })
}

function Resolve-GeneratedProjectPath {
    param(
        [string]$ProjectPath = '',
        [string]$Root = ''
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        $Root = Get-GeneratedProjectRoot
    }

    $resolvedRoot = [System.IO.Path]::GetFullPath($Root)
    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        $latest = Get-GeneratedProjectList -Root $resolvedRoot | Select-Object -First 1
        if ($null -eq $latest) {
            throw "no generated projects found under $resolvedRoot"
        }
        return $latest.project_dir
    }

    if (-not (Test-Path $ProjectPath)) {
        throw "generated project not found: $ProjectPath"
    }

    $resolvedProject = [System.IO.Path]::GetFullPath($ProjectPath)
    if (-not $resolvedProject.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "project path is outside generated root: $resolvedProject"
    }

    return $resolvedProject
}

function Get-GeneratedProjectMetadata {
    param(
        [Parameter(Mandatory)][string]$ProjectPath
    )

    $configPath = Join-Path $ProjectPath 'project.config.json'
    $specPath = Join-Path $ProjectPath 'build-spec.json'
    $config = $null
    $spec = $null

    if (Test-Path $configPath) {
        $config = Get-Content $configPath -Raw | ConvertFrom-Json
    }
    if (Test-Path $specPath) {
        $spec = Get-Content $specPath -Raw | ConvertFrom-Json
    }

    return [pscustomobject]@{
        project_dir = $ProjectPath
        appid       = if ($config) { [string]$config.appid } else { '' }
        projectname = if ($config) { [string]$config.projectname } else { '' }
        template    = if ($spec -and $spec.target) { [string]$spec.target.template } else { '' }
        prompt      = if ($spec -and $spec.task) { [string]$spec.task.title } else { '' }
        config_path = $configPath
    }
}

function Invoke-GeneratedProjectSetAppId {
    param(
        [string]$ProjectPath = '',
        [Parameter(Mandatory)][string]$AppId,
        [string]$ProjectName = '',
        [bool]$RequireConfirm = $false
    )

    $resolvedProject = Resolve-GeneratedProjectPath -ProjectPath $ProjectPath
    $metadata = Get-GeneratedProjectMetadata -ProjectPath $resolvedProject
    $configPath = $metadata.config_path
    if (-not (Test-Path $configPath)) {
        return @{
            status      = 'failed'
            reason      = 'missing_project_config'
            project_dir = $resolvedProject
        }
    }

    $description = "mode=generated-set-appid project=$resolvedProject appid=$AppId"
    if (-not (Confirm-DeployAction -Description $description -RequireConfirm $RequireConfirm)) {
        return @{
            status      = 'cancelled'
            project_dir = $resolvedProject
            appid       = $metadata.appid
        }
    }

    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $config.appid = $AppId
    if (-not [string]::IsNullOrWhiteSpace($ProjectName)) {
        $config.projectname = $ProjectName
    }

    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath -Encoding UTF8
    $updated = Get-GeneratedProjectMetadata -ProjectPath $resolvedProject

    return @{
        status      = 'success'
        project_dir = $resolvedProject
        appid       = $updated.appid
        projectname = $updated.projectname
        template    = $updated.template
    }
}

function Invoke-GeneratedProjectOpen {
    param(
        [string]$ProjectPath = ''
    )

    $resolvedProject = Resolve-GeneratedProjectPath -ProjectPath $ProjectPath
    return Invoke-OpenProject -ProjectPath $resolvedProject
}

function Invoke-GeneratedProjectPreview {
    param(
        [string]$ProjectPath = '',
        [bool]$RequireConfirm = $false
    )

    $resolvedProject = Resolve-GeneratedProjectPath -ProjectPath $ProjectPath
    $metadata = Get-GeneratedProjectMetadata -ProjectPath $resolvedProject
    $port = Get-WechatDevtoolsPort
    $description = "mode=generated-preview project=$resolvedProject appid=$($metadata.appid)"

    if (-not (Confirm-DeployAction -Description $description -RequireConfirm $RequireConfirm)) {
        return @{
            status      = 'cancelled'
            project_dir = $resolvedProject
            appid       = $metadata.appid
            template    = $metadata.template
        }
    }

    $result = Invoke-WechatCliCommand -Arguments @(
        'preview',
        '--project', $resolvedProject,
        '--port', [string]$port
    )

    return @{
        status      = if ($result.success) { 'success' } else { 'failed' }
        project_dir = $resolvedProject
        appid       = $metadata.appid
        template    = $metadata.template
        port        = $port
        output      = if ($result.parsed) { $result.parsed } else { $result.raw }
        exit_code   = $result.exit_code
    }
}

function Invoke-GeneratedProjectDeployGuard {
    param(
        [string]$ProjectPath = ''
    )

    $resolvedProject = Resolve-GeneratedProjectPath -ProjectPath $ProjectPath
    $metadata = Get-GeneratedProjectMetadata -ProjectPath $resolvedProject

    if ([string]::Equals($metadata.appid, 'touristappid', [System.StringComparison]::OrdinalIgnoreCase)) {
        return @{
            status      = 'denied'
            reason      = 'tourist_appid_not_deployable'
            project_dir = $resolvedProject
            appid       = $metadata.appid
            template    = $metadata.template
        }
    }

    return @{
        status      = 'eligible'
        reason      = 'appid_allows_deploy'
        project_dir = $resolvedProject
        appid       = $metadata.appid
        template    = $metadata.template
    }
}

function Invoke-GeneratedProjectUpload {
    param(
        [string]$ProjectPath = '',
        [string]$Version = '1.0.0',
        [string]$Desc = '',
        [bool]$RequireConfirm = $true,
        [bool]$DryRun = $false
    )

    $resolvedProject = Resolve-GeneratedProjectPath -ProjectPath $ProjectPath
    $metadata = Get-GeneratedProjectMetadata -ProjectPath $resolvedProject
    $guard = Invoke-GeneratedProjectDeployGuard -ProjectPath $resolvedProject
    if ($guard.status -ne 'eligible') {
        return @{
            status      = 'denied'
            reason      = $guard.reason
            project_dir = $resolvedProject
            appid       = $metadata.appid
            template    = $metadata.template
        }
    }

    $description = "mode=generated-upload project=$resolvedProject appid=$($metadata.appid) version=$Version"
    if (-not [string]::IsNullOrWhiteSpace($Desc)) {
        $description += " desc=$Desc"
    }
    if (-not (Confirm-DeployAction -Description $description -RequireConfirm $RequireConfirm)) {
        return @{
            status      = 'cancelled'
            project_dir = $resolvedProject
            appid       = $metadata.appid
            template    = $metadata.template
        }
    }

    if ($DryRun) {
        $port = Get-WechatDevtoolsPort
        return @{
            status      = 'dry_run'
            project_dir = $resolvedProject
            appid       = $metadata.appid
            template    = $metadata.template
            version     = $Version
            desc        = $Desc
            port        = $port
        }
    }

    $requirement = Resolve-WechatReleaseSetupRequirement -ActionName 'generated_upload' -AllowInteractiveSetup $RequireConfirm -WorkspaceRoot (Split-Path $PSScriptRoot -Parent)
    if ($requirement.status -ne 'ready') {
        return @{
            status      = 'needs_release_setup'
            reason      = 'local_real_deploy_config_required'
            project_dir = $resolvedProject
            appid       = $metadata.appid
            template    = $metadata.template
            readiness   = $requirement.readiness
        }
    }

    $port = Get-WechatDevtoolsPort

    $result = Invoke-WechatCliCommand -Arguments @(
        'upload',
        '--project', $resolvedProject,
        '--port', [string]$port,
        '--robot', '1'
    )

    return @{
        status      = if ($result.success) { 'success' } else { 'failed' }
        project_dir = $resolvedProject
        appid       = $metadata.appid
        template    = $metadata.template
        version     = $Version
        desc        = $Desc
        port        = $port
        output      = if ($result.parsed) { $result.parsed } else { $result.raw }
        exit_code   = $result.exit_code
    }
}

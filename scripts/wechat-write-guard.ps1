[CmdletBinding()]
param()

$script:SandboxProjectPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'sandbox\fake-project'

function Resolve-BackupRelativePath {
    param(
        [string]$ProjectPath,
        [string]$FilePath
    )

    if ([string]::IsNullOrWhiteSpace($FilePath)) {
        return $null
    }

    $relativePath = $FilePath
    if ([System.IO.Path]::IsPathRooted($FilePath)) {
        $projectRoot = (Resolve-Path $ProjectPath).Path.TrimEnd('\')
        $resolvedFile = Resolve-Path $FilePath -ErrorAction SilentlyContinue
        if ($resolvedFile) {
            $resolvedPath = $resolvedFile.Path
            if ($resolvedPath.StartsWith($projectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relativePath = $resolvedPath.Substring($projectRoot.Length).TrimStart('\', '/')
            }
            else {
                $relativePath = Split-Path $resolvedPath -Leaf
            }
        }
        else {
            $relativePath = Split-Path $FilePath -Leaf
        }
    }

    if ([string]::IsNullOrWhiteSpace($relativePath)) {
        return $null
    }

    return $relativePath
}

function Ensure-GitSafeDirectory {
    param([string]$ProjectPath)

    $resolvedPath = (Get-Item $ProjectPath).FullName
    $env:GIT_CONFIG_COUNT = '2'
    $env:GIT_CONFIG_KEY_0 = 'safe.directory'
    $env:GIT_CONFIG_VALUE_0 = $resolvedPath
    $env:GIT_CONFIG_KEY_1 = 'core.quotepath'
    $env:GIT_CONFIG_VALUE_1 = 'false'
}

function Invoke-GitProjectCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectPath,
        [Parameter(Mandatory)][string[]]$GitArguments
    )

    if (-not (Test-Path $ProjectPath)) {
        throw "Project path not found: $ProjectPath"
    }

    Push-Location $ProjectPath
    try {
        Ensure-GitSafeDirectory -ProjectPath $ProjectPath
        $output = & git @GitArguments 2>&1 | Out-String
        return @{
            output    = $output.Trim()
            exit_code = $LASTEXITCODE
            success   = ($LASTEXITCODE -eq 0)
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-SafeWrite {
    param(
        [string]$ProjectPath = $script:SandboxProjectPath,
        [string]$Description,
        [scriptblock]$WriteAction,
        [bool]$RequireConfirm = $true,
        [string[]]$FilesToBackup = @()
    )

    if (-not (Test-Path $ProjectPath)) {
        throw "Project path not found: $ProjectPath"
    }

    Push-Location $ProjectPath
    try {
        Ensure-GitSafeDirectory -ProjectPath $ProjectPath
        $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
        if ($FilesToBackup -and $FilesToBackup.Count -gt 0) {
            foreach ($filePath in $FilesToBackup) {
                $relativePath = Resolve-BackupRelativePath -ProjectPath $ProjectPath -FilePath $filePath
                if ($relativePath) {
                    Invoke-GitProjectCommand -ProjectPath $ProjectPath -GitArguments @('add', '--', $relativePath) | Out-Null
                }
            }
        }
        else {
            Invoke-GitProjectCommand -ProjectPath $ProjectPath -GitArguments @('add', '-u') | Out-Null
        }

        Invoke-GitProjectCommand -ProjectPath $ProjectPath -GitArguments @('commit', '-m', "auto-backup: before $Description [$timestamp]", '--allow-empty') | Out-Null
    }
    finally {
        Pop-Location
    }

    if ($RequireConfirm) {
        Write-Host '=== Pending write action ==='
        Write-Host $Description
        Write-Host '========================'
        Write-Host 'Type yes to continue. Any other input cancels.'
        $confirm = if ($env:WRITE_GUARD_AUTO_CONFIRM) {
            $env:WRITE_GUARD_AUTO_CONFIRM
        }
        else {
            Read-Host
        }
        if ($confirm -ne 'yes') {
            Write-Host '[WRITE] Cancelled.'
            return @{
                status = 'cancelled'
            }
        }
    }

    try {
        & $WriteAction
        Write-Host "[WRITE] Success: $Description"
        return @{
            status = 'success'
        }
    }
    catch {
        Write-Warning '[WRITE] Failed, rolling back automatically.'
        Push-Location $ProjectPath
        try {
            Ensure-GitSafeDirectory -ProjectPath $ProjectPath
            if ($FilesToBackup.Count -gt 0) {
                foreach ($filePath in $FilesToBackup) {
                    $relativePath = Resolve-BackupRelativePath -ProjectPath $ProjectPath -FilePath $filePath
                    if ($relativePath) {
                        Invoke-GitProjectCommand -ProjectPath $ProjectPath -GitArguments @('checkout', 'HEAD', '--', $relativePath) | Out-Null
                    }
                }
            }
            else {
                Invoke-GitProjectCommand -ProjectPath $ProjectPath -GitArguments @('checkout', 'HEAD', '--', '.') | Out-Null
            }
            Invoke-GitProjectCommand -ProjectPath $ProjectPath -GitArguments @('commit', '--allow-empty', '-m', "revert: rollback after $Description") | Out-Null
        }
        finally {
            Pop-Location
        }

        return @{
            status = 'reverted'
            error  = $_.Exception.Message
        }
    }
}

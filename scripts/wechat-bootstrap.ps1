[CmdletBinding()]
param()

. "$PSScriptRoot\wechat-doctor.ps1"

function Invoke-WechatBootstrap {
    [CmdletBinding()]
    param(
        [string]$RepoRoot = '',
        [bool]$RunDoctor = $true
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Split-Path $PSScriptRoot -Parent
    }
    $resolvedRoot = [System.IO.Path]::GetFullPath($RepoRoot)

    $requiredDirs = @(
        (Join-Path $resolvedRoot 'generated'),
        (Join-Path $resolvedRoot 'artifacts'),
        (Join-Path $resolvedRoot 'artifacts\wechat-devtools'),
        (Join-Path $resolvedRoot 'specs'),
        (Join-Path $resolvedRoot 'templates'),
        (Join-Path $resolvedRoot 'scripts')
    )

    $created = @()
    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $created += $dir
        }
    }

    $doctor = @{
        status = 'skipped'
    }
    if ($RunDoctor) {
        $doctor = Invoke-WechatDoctor -ArtifactsRoot (Join-Path $resolvedRoot 'artifacts\wechat-devtools')
    }

    return @{
        status        = 'success'
        repo_root     = $resolvedRoot
        created_dirs  = $created
        doctor_status = if ($doctor.status) { $doctor.status } else { 'unknown' }
        doctor        = $doctor
        next_steps    = @(
            '. .\scripts\wechat.ps1',
            'Invoke-WechatDoctor',
            'Invoke-WechatCreate -Prompt "build a notebook mini program" -Open $true -Preview $true'
        )
    }
}


. "$PSScriptRoot\wechat-doctor.ps1"

function Get-SharedDoctorFixturesFingerprint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $paths = @(
        (Join-Path $RepoRoot 'scripts\wechat-doctor.ps1'),
        (Join-Path $RepoRoot 'scripts\wechat-get-port.ps1'),
        (Join-Path $RepoRoot 'scripts\test-doctor-report-path.ps1'),
        (Join-Path $RepoRoot 'scripts\test-doctor-report-write-failure.ps1'),
        (Join-Path $RepoRoot 'scripts\test-wechat-doctor-runtime.ps1')
    ) | Where-Object { Test-Path $_ }

    $entries = foreach ($path in ($paths | Sort-Object -Unique)) {
        $item = Get-Item $path -ErrorAction SilentlyContinue
        if ($null -ne $item -and -not $item.PSIsContainer) {
            '{0}|{1}' -f $item.FullName.ToLowerInvariant(), $item.LastWriteTimeUtc.Ticks
        }
    }

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes(($entries -join "`n"))
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-SharedDoctorFixtures {
    param(
        [string]$RepoRoot = '',
        [switch]$ForceRefresh
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Split-Path $PSScriptRoot -Parent
    }

    $artifactsRoot = Join-Path $RepoRoot 'artifacts\wechat-devtools\doctor-fixtures'
    $cachePath = Join-Path $artifactsRoot 'shared-doctor-cache.json'
    $fingerprint = Get-SharedDoctorFixturesFingerprint -RepoRoot $RepoRoot

    if (-not $ForceRefresh -and (Test-Path $cachePath)) {
        try {
            $cached = Get-Content -Path $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            if (
                $cached.fingerprint -eq $fingerprint -and
                $null -ne $cached.doctor_result -and
                $null -ne $cached.doctor_failure_result -and
                (Test-Path ([string]$cached.doctor_result.report_path))
            ) {
                return [pscustomobject]@{
                    fromCache = $true
                    cachePath = $cachePath
                    fingerprint = $fingerprint
                    doctorResult = [pscustomobject]$cached.doctor_result
                    doctorFailureResult = [pscustomobject]$cached.doctor_failure_result
                }
            }
        }
        catch {
        }
    }

    New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null

    $normalArtifactsRoot = Join-Path $artifactsRoot 'normal'
    $doctorResult = Invoke-WechatDoctor -ArtifactsRoot $normalArtifactsRoot
    $doctorFailureResult = Invoke-WechatDoctor -SimulateWriteFailure

    $payload = [pscustomobject]@{
        fingerprint = $fingerprint
        generated_at = (Get-Date).ToString('o')
        doctor_result = $doctorResult
        doctor_failure_result = $doctorFailureResult
    }
    $payload | ConvertTo-Json -Depth 12 | Set-Content -Path $cachePath -Encoding UTF8

    return [pscustomobject]@{
        fromCache = $false
        cachePath = $cachePath
        fingerprint = $fingerprint
        doctorResult = $doctorResult
        doctorFailureResult = $doctorFailureResult
    }
}

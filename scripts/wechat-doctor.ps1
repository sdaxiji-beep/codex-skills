[CmdletBinding()]
param(
    [string]$ArtifactsRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools'),
    [switch]$SimulateWriteFailure
)

. "$PSScriptRoot\wechat-get-port.ps1"

function Test-WechatCliPath {
    [CmdletBinding()]
    param()

    $candidates = @(
        'C:\Program Files (x86)\Tencent\微信web开发者工具\cli.bat',
        'C:\Program Files (x86)\Tencent\微信开发者工具\cli.bat'
    )
    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return @{
                ok   = $true
                path = $candidate
            }
        }
    }

    return @{
        ok   = $false
        path = ''
    }
}

function Test-WechatDevtoolsOpenApi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Port
    )

    $uri = "http://127.0.0.1:$Port/v2/open"
    try {
        [void](Invoke-RestMethod -Uri $uri -Method GET -TimeoutSec 3)
        return @{
            ok  = $true
            uri = $uri
        }
    }
    catch {
        return @{
            ok     = $false
            uri    = $uri
            reason = $_.Exception.Message
        }
    }
}

function Invoke-WechatDoctor {
    [CmdletBinding()]
    param(
        [string]$ArtifactsRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'artifacts\wechat-devtools'),
        [switch]$SimulateWriteFailure
    )

    $doctorDir = Join-Path $ArtifactsRoot 'doctor'
    New-Item -ItemType Directory -Force -Path $doctorDir | Out-Null
    $reportPath = Join-Path $doctorDir 'doctor-summary.json'

    $port = Get-WechatDevtoolsPort
    $apiCheck = Test-WechatDevtoolsOpenApi -Port $port
    $cliCheck = Test-WechatCliPath
    $generatedRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'generated'
    $generatedCount = if (Test-Path $generatedRoot) { @(Get-ChildItem $generatedRoot -Directory).Count } else { 0 }

    $checks = @(
        @{
            name   = 'devtools_port_detected'
            ok     = ($port -gt 0)
            detail = "port=$port"
        },
        @{
            name   = 'devtools_open_api'
            ok     = [bool]$apiCheck.ok
            detail = if ($apiCheck.ok) { $apiCheck.uri } else { $apiCheck.reason }
        },
        @{
            name   = 'cli_path_exists'
            ok     = [bool]$cliCheck.ok
            detail = if ($cliCheck.ok) { $cliCheck.path } else { 'cli_not_found' }
        },
        @{
            name   = 'generated_root_exists'
            ok     = (Test-Path $generatedRoot)
            detail = "root=$generatedRoot count=$generatedCount"
        }
    )

    $allOk = (@($checks | Where-Object { -not $_.ok }).Count -eq 0)
    $result = @{
        test                   = 'doctor'
        pass                   = ($allOk -and -not $SimulateWriteFailure)
        status                 = if ($SimulateWriteFailure) { 'warn' } elseif ($allOk) { 'pass' } else { 'warn' }
        process_exit_code      = if ($SimulateWriteFailure) { 2 } elseif ($allOk) { 0 } else { 1 }
        report_path            = $reportPath
        interface_version      = 'v1'
        has_failure_summary_v2 = $true
        port                   = $port
        checks                 = $checks
        summary                = @{
            total_checks  = $checks.Count
            passed_checks = @($checks | Where-Object { $_.ok }).Count
            failed_checks = @($checks | Where-Object { -not $_.ok }).Count
        }
    }

    if (-not $SimulateWriteFailure) {
        $result | ConvertTo-Json -Depth 5 | Set-Content -Path $reportPath -Encoding UTF8
    }

    return $result
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-WechatDoctor -ArtifactsRoot $ArtifactsRoot -SimulateWriteFailure:$SimulateWriteFailure | ConvertTo-Json -Depth 5
}

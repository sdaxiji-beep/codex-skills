[CmdletBinding()]
param()

. "$PSScriptRoot\wechat-get-port.ps1"
if (-not (Get-Command Wait-For-DevtoolsPort -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-env-recovery.ps1"
}

function Invoke-OpenProject {
    param(
        [Parameter(Mandatory)]
        [string]$ProjectPath,
        [string]$CliPath = $null,
        [object]$ServicePort = 'auto'
    )

    if (-not $CliPath) {
        $CliPath = Get-ChildItem -Path 'C:\Program Files (x86)\Tencent' -Filter 'cli.bat' -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
    }

    if (-not $CliPath -or -not (Test-Path $CliPath)) {
        return @{
            status = 'failed'
            reason = 'cli.bat not found'
        }
    }

    if (-not (Test-Path $ProjectPath)) {
        return @{
            status = 'failed'
            reason = "project path not found: $ProjectPath"
        }
    }

    $configFile = Join-Path $ProjectPath 'project.config.json'
    if (-not (Test-Path $configFile)) {
        return @{
            status = 'failed'
            reason = 'missing project.config.json'
        }
    }

    $port = if (($ServicePort -eq 'auto') -or [string]::IsNullOrWhiteSpace([string]$ServicePort)) {
        Get-WechatDevtoolsPort
    }
    else {
        [int]$ServicePort
    }

    Write-Host "[OPEN] opening project: $ProjectPath"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'cmd.exe'
    $psi.Arguments = "/c """"$CliPath"" open --project ""$ProjectPath"""""
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $proc = [System.Diagnostics.Process]::Start($psi)
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    $stdout = $proc.StandardOutput.ReadToEnd()
    if (-not $proc.WaitForExit(10000)) {
        $proc.Kill()
        return @{
            status = 'warning'
            reason = 'open command timeout'
            port   = $port
        }
    }

    $stderr = $stderrTask.Result
    if ($proc.ExitCode -ne 0) {
        Write-Verbose "[OPEN] stderr: $stderr"
        return @{
            status = 'warning'
            reason = if ($stderr) { $stderr.Trim() } else { $stdout.Trim() }
            port   = $port
        }
    }

    $recovery = Wait-For-DevtoolsPort -RetryCount 5 -DelaySeconds 2
    if ([string]$recovery.status -eq 'ready') {
        return @{
            status  = 'success'
            project = $ProjectPath
            port    = [int]$recovery.port
        }
    }

    return @{
        status = 'warning'
        reason = 'open command sent but response could not be confirmed'
        port   = $port
        env_recovery = $recovery
    }
}

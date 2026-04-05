[CmdletBinding()]
param()

if (-not (Get-Command Get-WechatDevtoolsPort -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-get-port.ps1"
}

if (-not (Get-Command Test-WechatCliPath -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-doctor.ps1"
}

function Test-WechatOpenApiReady {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][int]$Port
    )

    $uri = "http://127.0.0.1:$Port/v2/open"
    try {
        [void](Invoke-RestMethod -Uri $uri -Method GET -TimeoutSec 2)
        return [pscustomobject]@{
            ok = $true
            uri = $uri
            reason = ''
        }
    }
    catch {
        return [pscustomobject]@{
            ok = $false
            uri = $uri
            reason = $_.Exception.Message
        }
    }
}

function Get-WechatEnvRecoveryGuidance {
    [CmdletBinding()]
    param(
        [int]$Port = 0,
        [string]$Reason = ''
    )

    return @(
        'Ensure WeChat DevTools 2.01.x is fully open and not still starting in the background.',
        'Open any project once in DevTools to allow the local open API service to attach.',
        ('Verify the detected service port is reachable: http://127.0.0.1:{0}/v2/open' -f $Port),
        'If the API still does not respond, restart WeChat DevTools and retry the real drill.',
        ('Last observed failure: {0}' -f $(if ([string]::IsNullOrWhiteSpace($Reason)) { 'unknown' } else { $Reason }))
    )
}

function Wait-For-DevtoolsPort {
    [CmdletBinding()]
    param(
        [int]$RetryCount = 5,
        [int]$DelaySeconds = 3
    )

    $attempts = @()
    for ($i = 1; $i -le $RetryCount; $i++) {
        $port = Get-WechatDevtoolsPort
        $probe = Test-WechatOpenApiReady -Port $port
        $attempts += [pscustomobject]@{
            attempt = $i
            port = $port
            ok = [bool]$probe.ok
            reason = [string]$probe.reason
        }

        if ($probe.ok) {
            return [pscustomobject]@{
                status = 'ready'
                port = $port
                attempts = @($attempts)
                guidance = @()
            }
        }

        if ($i -lt $RetryCount) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    $last = @($attempts)[-1]
    return [pscustomobject]@{
        status = 'blocked'
        port = [int]$last.port
        attempts = @($attempts)
        guidance = @(Get-WechatEnvRecoveryGuidance -Port ([int]$last.port) -Reason ([string]$last.reason))
    }
}

function Invoke-WechatEnvRecovery {
    [CmdletBinding()]
    param(
        [int]$RetryCount = 5,
        [int]$DelaySeconds = 3
    )

    $cli = Test-WechatCliPath
    $wait = Wait-For-DevtoolsPort -RetryCount $RetryCount -DelaySeconds $DelaySeconds
    return [pscustomobject]@{
        status = if ($cli.ok -and $wait.status -eq 'ready') { 'ready' } else { 'blocked' }
        cli_ok = [bool]$cli.ok
        cli_path = [string]$cli.path
        port = [int]$wait.port
        attempts = @($wait.attempts)
        guidance = @($wait.guidance)
    }
}

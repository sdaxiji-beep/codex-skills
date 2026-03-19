[CmdletBinding()]
param()

function Test-WechatPortHttp {
    param([int]$Port)

    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:$Port/v2/open" -Method GET -TimeoutSec 1 | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Get-IdePortCandidates {
    $candidates = New-Object System.Collections.Generic.List[int]

    $patterns = @(
        "$env:LOCALAPPDATA\*\User Data\*\Default\.ide",
        "$env:LOCALAPPDATA\*\User Data\Default\.ide",
        "$env:USERPROFILE\AppData\Local\*\User Data\*\Default\.ide",
        "$env:USERPROFILE\AppData\Local\*\User Data\Default\.ide"
    )

    foreach ($pattern in $patterns) {
        try {
            $files = Get-ChildItem -Path $pattern -ErrorAction Stop |
                Sort-Object LastWriteTime -Descending
        }
        catch {
            continue
        }
        foreach ($file in $files) {
            $raw = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $raw) { continue }
            $portText = $raw.Trim()
            if ($portText -match '^\d+$') {
                $port = [int]$portText
                if ($port -gt 1024 -and $port -lt 65535 -and -not $candidates.Contains($port)) {
                    $candidates.Add($port)
                }
            }
        }
    }

    return $candidates.ToArray()
}

function Get-NetstatListeningCandidates {
    $wechatPids = @(Get-Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ProcessName -match 'wechat|devtools|weixin|wx' -or
            $_.ProcessName -match '微信'
        } |
        Select-Object -ExpandProperty Id)

    if ($wechatPids.Count -eq 0) {
        return @()
    }

    $ports = New-Object System.Collections.Generic.List[int]
    $lines = netstat -ano | Select-String 'LISTENING'
    foreach ($line in $lines) {
        $text = ($line.ToString().Trim() -replace '\s+', ' ')
        $parts = $text.Split(' ')
        if ($parts.Count -lt 5) { continue }
        $local = $parts[1]
        $pidText = $parts[-1]
        if ($pidText -notmatch '^\d+$') { continue }
        $procId = [int]$pidText
        if ($wechatPids -notcontains $procId) { continue }
        $portText = ($local -split ':')[-1]
        if ($portText -match '^\d+$') {
            $port = [int]$portText
            if ($port -gt 1024 -and $port -lt 65535 -and -not $ports.Contains($port)) {
                $ports.Add($port)
            }
        }
    }
    return ,$ports.ToArray()
}

function Get-WechatDevtoolsPort {
    param([int]$DefaultPort = 34757)

    $idePorts = @(Get-IdePortCandidates)
    foreach ($port in $idePorts) {
        if (Test-WechatPortHttp -Port $port) {
            Write-Verbose "[PORT] detected and reachable via .ide: $port"
            return $port
        }
    }

    if ($idePorts.Count -gt 0) {
        Write-Verbose "[PORT] .ide found but HTTP unreachable, use latest ide port: $($idePorts[0])"
        return [int]$idePorts[0]
    }

    $probePorts = New-Object System.Collections.Generic.List[int]
    foreach ($port in @(17530, 51079, 34757, 23392, 9420, $DefaultPort)) {
        if ($port -gt 1024 -and $port -lt 65535 -and -not $probePorts.Contains($port)) {
            $probePorts.Add([int]$port)
        }
    }
    foreach ($port in (Get-NetstatListeningCandidates)) {
        if (-not $probePorts.Contains($port)) {
            $probePorts.Add([int]$port)
        }
    }

    foreach ($port in $probePorts) {
        if (Test-WechatPortHttp -Port $port) {
            Write-Verbose "[PORT] detected by HTTP probe: $port"
            return $port
        }
    }

    Write-Verbose "[PORT] unable to detect active devtools port, fallback default: $DefaultPort"
    return $DefaultPort
}

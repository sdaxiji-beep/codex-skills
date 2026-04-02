function Get-ProjectScopedAutomatorPort {
    [CmdletBinding()]
    param(
        [string]$ProjectPath = '',
        [int]$BasePort = 9420,
        [int]$PortSpan = 40
    )

    if ($PortSpan -le 0) {
        throw "PortSpan must be greater than 0."
    }

    if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
        return $BasePort
    }

    try {
        $normalized = [System.IO.Path]::GetFullPath($ProjectPath).ToLowerInvariant()
    }
    catch {
        $normalized = ([string]$ProjectPath).ToLowerInvariant()
    }

    $hash = [System.Security.Cryptography.SHA1]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($normalized)
        $digest = $hash.ComputeHash($bytes)
        $value = [BitConverter]::ToUInt32($digest, 0)
        return ($BasePort + ($value % [uint32]$PortSpan))
    }
    finally {
        $hash.Dispose()
    }
}

function Get-ProjectScopedAutomatorPortCandidates {
    [CmdletBinding()]
    param(
        [string]$ProjectPath = '',
        [int]$BasePort = 9420,
        [int]$PortSpan = 40,
        [int]$ExtraScan = 20
    )

    $preferred = Get-ProjectScopedAutomatorPort -ProjectPath $ProjectPath -BasePort $BasePort -PortSpan $PortSpan
    $candidateSet = [System.Collections.Generic.HashSet[int]]::new()
    $ordered = New-Object System.Collections.Generic.List[int]

    foreach ($candidate in @($preferred) + ($BasePort..($BasePort + $PortSpan - 1)) + (($BasePort + $PortSpan)..($BasePort + $PortSpan + $ExtraScan))) {
        if ($candidateSet.Add([int]$candidate)) {
            $ordered.Add([int]$candidate) | Out-Null
        }
    }

    return @($ordered.ToArray())
}

. "$PSScriptRoot\wechat-readonly-flow.ps1"
. "$PSScriptRoot\wechat-get-port.ps1"
. "$PSScriptRoot\Write-AtomicJsonCache.ps1"

function ConvertTo-HashtableDeep {
    param(
        [Parameter(ValueFromPipeline = $true)]
        $InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in $InputObject.Keys) {
            $table[$key] = ConvertTo-HashtableDeep -InputObject $InputObject[$key]
        }
        return $table
    }

    if ($InputObject -is [pscustomobject]) {
        $table = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $table[$property.Name] = ConvertTo-HashtableDeep -InputObject $property.Value
        }
        return $table
    }

    if (
        $InputObject -is [System.Collections.IEnumerable] -and
        $InputObject -isnot [string]
    ) {
        $items = New-Object System.Collections.Generic.List[object]
        foreach ($item in $InputObject) {
            [void]$items.Add((ConvertTo-HashtableDeep -InputObject $item))
        }
        return ,($items.ToArray())
    }

    return $InputObject
}

function Normalize-ReadonlyFlowResult {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$FlowResult
    )

    if ($FlowResult.ContainsKey('page_signature') -and $FlowResult.page_signature -is [hashtable]) {
        $signature = $FlowResult.page_signature

        if ($null -eq $signature.candidates) {
            $signature.candidates = @()
        }
        elseif ($signature.candidates -is [string]) {
            $signature.candidates = @([string]$signature.candidates)
        }
        else {
            $signature.candidates = @($signature.candidates)
        }

        if ($null -eq $signature.issues) {
            $signature.issues = @()
        }
        elseif ($signature.issues -is [string]) {
            $signature.issues = @([string]$signature.issues)
        }
        else {
            $signature.issues = @($signature.issues)
        }

        if ($null -eq $signature.page_data_keys) {
            $signature.page_data_keys = @()
        }
        elseif ($signature.page_data_keys -is [string]) {
            $signature.page_data_keys = @([string]$signature.page_data_keys)
        }
        else {
            $signature.page_data_keys = @($signature.page_data_keys)
        }

        if ($null -eq $signature.page_elements -or $signature.page_elements -isnot [hashtable]) {
            $signature.page_elements = @{}
        }

        $FlowResult.page_signature = $signature
    }

    return $FlowResult
}

function Get-SharedReadonlyFlowFingerprint {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $paths = @(
        (Join-Path $RepoRoot 'scripts\wechat-readonly-flow.ps1'),
        (Join-Path $RepoRoot 'scripts\wechat-get-port.ps1'),
        (Join-Path $RepoRoot 'probe-automator.js')
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

function Get-SharedReadonlyFlowResult {
    param(
        [string]$RepoRoot = '',
        [switch]$ForceRefresh
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $RepoRoot = Split-Path $PSScriptRoot -Parent
    }

    $artifactsRoot = Join-Path $RepoRoot 'artifacts\wechat-devtools\readonly-flow'
    $cachePath = Join-Path $artifactsRoot 'shared-readonly-flow-cache.json'
    $fingerprint = Get-SharedReadonlyFlowFingerprint -RepoRoot $RepoRoot
    $cacheTtlSeconds = 900

    if (-not $ForceRefresh -and (Test-Path $cachePath)) {
        try {
            $cached = Get-Content -Path $cachePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
            $generatedAt = Get-Date ([string]$cached.generated_at)
            if (
                $cached.fingerprint -eq $fingerprint -and
                $null -ne $cached.flow_result -and
                ((Get-Date) - $generatedAt).TotalSeconds -lt $cacheTtlSeconds
            ) {
                $flowResult = ConvertTo-HashtableDeep -InputObject $cached.flow_result
                $flowResult = Normalize-ReadonlyFlowResult -FlowResult $flowResult
                return [pscustomobject]@{
                    fromCache = $true
                    cachePath = $cachePath
                    fingerprint = $fingerprint
                    flowResult = $flowResult
                    devtoolsPort = if ($null -ne $cached.devtools_port) { [int]$cached.devtools_port } else { 0 }
                }
            }
        }
        catch {
        }
    }

    New-Item -ItemType Directory -Path $artifactsRoot -Force | Out-Null
    $flowResult = ConvertTo-HashtableDeep -InputObject (Invoke-FlowViaAutomator)
    if ($flowResult -is [hashtable]) {
        if (-not $flowResult.ContainsKey('devtools_port')) {
            $flowResult.devtools_port = [int](Get-WechatDevtoolsPort)
        }
        $flowResult = Normalize-ReadonlyFlowResult -FlowResult $flowResult
    }

    $payload = [pscustomobject]@{
        fingerprint = $fingerprint
        generated_at = (Get-Date).ToString('o')
        devtools_port = if ($flowResult -is [hashtable] -and $flowResult.ContainsKey('devtools_port')) { [int]$flowResult.devtools_port } else { 0 }
        flow_result = $flowResult
    }
    Write-AtomicJsonCache -Path $cachePath -InputObject $payload -Depth 12

    return [pscustomobject]@{
        fromCache = $false
        cachePath = $cachePath
        fingerprint = $fingerprint
        flowResult = $flowResult
        devtoolsPort = if ($flowResult -is [hashtable] -and $flowResult.ContainsKey('devtools_port')) { [int]$flowResult.devtools_port } else { 0 }
    }
}

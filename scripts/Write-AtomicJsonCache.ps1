function Write-AtomicJsonCache {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$InputObject,

        [int]$Depth = 12
    )

    $directory = Split-Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    $tempPath = '{0}.tmp-{1}-{2}' -f $Path, [System.Diagnostics.Process]::GetCurrentProcess().Id, ([guid]::NewGuid().ToString('N'))
    try {
        $json = $InputObject | ConvertTo-Json -Depth $Depth
        [System.IO.File]::WriteAllText($tempPath, $json, (New-Object System.Text.UTF8Encoding($false)))
        Move-Item -Path $tempPath -Destination $Path -Force
    }
    finally {
        if (Test-Path $tempPath) {
            Remove-Item -Path $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        $Actual,
        $Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message Expected=$Expected Actual=$Actual"
    }
}

function Assert-In {
    param(
        $Actual,
        [object[]]$ExpectedSet,
        [string]$Message
    )

    if ($ExpectedSet -notcontains $Actual) {
        throw "$Message Actual=$Actual"
    }
}

function Assert-NotEmpty {
    param(
        $Value,
        [string]$Message
    )

    if ($null -eq $Value) {
        throw $Message
    }

    if ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) {
        throw $Message
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $hasValue = @($Value).Count -gt 0
        if (-not $hasValue) {
            throw $Message
        }
    }
}

function New-TestResult {
    param(
        [string]$Name,
        [hashtable]$Data
    )

    return [pscustomobject]($Data + @{ test = $Name })
}

if (-not ($global:WechatMcpBoundaryCache -is [hashtable])) {
    $global:WechatMcpBoundaryCache = @{}
}

. "$PSScriptRoot\Get-SharedP3OperationalFixtures.ps1"
. "$PSScriptRoot\Write-AtomicJsonCache.ps1"

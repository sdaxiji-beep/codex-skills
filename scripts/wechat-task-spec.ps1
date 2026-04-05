[CmdletBinding()]
param(
    [string]$TaskSpecJson = '',
    [switch]$Compile
)

if ($Compile -and -not (Get-Command Invoke-TaskSpecToBundle -ErrorAction SilentlyContinue)) {
    . "$PSScriptRoot\wechat-task-bundle-compiler.ps1"
}

function Test-WechatTaskSpecField {
    param(
        [Parameter(Mandatory)]$TaskSpec,
        [Parameter(Mandatory)][string]$Field
    )

    if ($TaskSpec -is [System.Collections.IDictionary]) {
        return $TaskSpec.Contains($Field) -or @($TaskSpec.Keys) -contains $Field
    }

    return $null -ne $TaskSpec.PSObject.Properties[$Field]
}

function New-WechatTaskTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('page', 'component')]$BundleKind
    )

    return [ordered]@{
        path = $Path
        bundle_kind = $BundleKind
    }
}

function New-WechatTaskAcceptanceCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Type,
        [Parameter(Mandatory)][string]$Target,
        [string]$Expected = ''
    )

    $check = [ordered]@{
        type = $Type
        target = $Target
    }

    if (-not [string]::IsNullOrWhiteSpace($Expected)) {
        $check.expected = $Expected
    }

    return $check
}

function New-WechatTaskRepairStrategy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Family,
        [int]$MaxRounds = 3,
        [string[]]$SupportedCodes = @()
    )

    return [ordered]@{
        family = $Family
        max_rounds = $MaxRounds
        supported_codes = @($SupportedCodes)
    }
}

function New-WechatTaskSpec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TaskIntent,
        [Parameter(Mandatory)][string]$TaskFamily,
        [Parameter(Mandatory)][string]$RouteMode,
        [Parameter(Mandatory)][string]$Goal,
        [hashtable[]]$TargetPages = @(),
        [hashtable[]]$RequiredComponents = @(),
        [hashtable]$AppPatch = @{},
        [hashtable[]]$AcceptanceChecks = @(),
        [hashtable]$RepairStrategy = @{},
        [hashtable]$RoutingConfig = @{}
    )

    $spec = [ordered]@{
        task_intent = $TaskIntent
        task_family = $TaskFamily
        route_mode = $RouteMode
        goal = $Goal
        target_pages = @($TargetPages)
        required_components = @($RequiredComponents)
        app_patch = if ($null -eq $AppPatch) { @{} } else { $AppPatch }
        acceptance_checks = @($AcceptanceChecks)
        repair_strategy = if ($null -eq $RepairStrategy) { @{} } else { $RepairStrategy }
        routing_config = if ($null -eq $RoutingConfig) { @{} } else { $RoutingConfig }
    }

    Test-WechatTaskSpec -TaskSpec $spec | Out-Null
    return $spec
}

function Test-WechatTaskSpec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$TaskSpec
    )

    if ($null -eq $TaskSpec) {
        throw 'TaskSpec cannot be null.'
    }

    $requiredFields = @(
        'task_family',
        'route_mode',
        'goal',
        'target_pages',
        'required_components',
        'app_patch',
        'acceptance_checks',
        'repair_strategy',
        'routing_config'
    )

    foreach ($field in $requiredFields) {
        if (-not (Test-WechatTaskSpecField -TaskSpec $TaskSpec -Field $field)) {
            throw "TaskSpec missing required field: $field"
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$TaskSpec.task_intent)) {
        throw 'TaskSpec.task_intent cannot be empty.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$TaskSpec.task_family)) {
        throw 'TaskSpec.task_family cannot be empty.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$TaskSpec.route_mode)) {
        throw 'TaskSpec.route_mode cannot be empty.'
    }
    if ([string]::IsNullOrWhiteSpace([string]$TaskSpec.goal)) {
        throw 'TaskSpec.goal cannot be empty.'
    }

    foreach ($page in @($TaskSpec.target_pages)) {
        if ([string]::IsNullOrWhiteSpace([string]$page.path)) {
            throw 'TaskSpec.target_pages[].path cannot be empty.'
        }
        if ([string]$page.bundle_kind -ne 'page') {
            throw 'TaskSpec.target_pages[].bundle_kind must be page.'
        }
    }

    foreach ($component in @($TaskSpec.required_components)) {
        if ([string]::IsNullOrWhiteSpace([string]$component.path)) {
            throw 'TaskSpec.required_components[].path cannot be empty.'
        }
        if ([string]$component.bundle_kind -ne 'component') {
            throw 'TaskSpec.required_components[].bundle_kind must be component.'
        }
    }

    foreach ($check in @($TaskSpec.acceptance_checks)) {
        if ([string]::IsNullOrWhiteSpace([string]$check.type)) {
            throw 'TaskSpec.acceptance_checks[].type cannot be empty.'
        }
        if ([string]::IsNullOrWhiteSpace([string]$check.target)) {
            throw 'TaskSpec.acceptance_checks[].target cannot be empty.'
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$TaskSpec.repair_strategy.family)) {
        throw 'TaskSpec.repair_strategy.family cannot be empty.'
    }
    if ([int]$TaskSpec.repair_strategy.max_rounds -lt 1) {
        throw 'TaskSpec.repair_strategy.max_rounds must be >= 1.'
    }

    return $true
}

function Invoke-WechatTaskSpec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$TaskSpec,
        [switch]$Compile
    )

    Test-WechatTaskSpec -TaskSpec $TaskSpec | Out-Null
    $result = [ordered]@{
        status = 'success'
        task_spec = $TaskSpec
    }

    if ($Compile) {
        if (-not (Get-Command Invoke-TaskSpecToBundle -ErrorAction SilentlyContinue)) {
            . "$PSScriptRoot\wechat-task-bundle-compiler.ps1"
        }

        $compiled = Invoke-TaskSpecToBundle -TaskSpec $TaskSpec
        $result.compiled = $compiled
        $result.page_bundle = $compiled.page_bundle
        $result.component_bundle = $compiled.component_bundle
        $result.app_patch = $compiled.app_patch
    }

    return [pscustomobject]$result
}

if (-not [string]::IsNullOrWhiteSpace($TaskSpecJson)) {
    $parsedTaskSpec = $TaskSpecJson | ConvertFrom-Json
    Invoke-WechatTaskSpec -TaskSpec $parsedTaskSpec -Compile:$Compile
}

function Add-GenerationGateAppJsonV1Error {
    param(
        [Parameter(Mandatory)]$Result,
        [Parameter(Mandatory)][string]$Message,
        [switch]$Hard
    )

    $Result.Errors.Add($Message)
    if ($Hard) {
        $Result.Status = 'hard_fail'
        return
    }

    if ($Result.Status -eq 'pass') {
        $Result.Status = 'retryable_fail'
    }
}

function Invoke-GenerationGateAppJsonV1 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonPayload,

        [string]$TargetWorkspace = (Get-Location).Path
    )

    $result = [pscustomobject]@{
        Status = 'pass'
        Errors = [System.Collections.Generic.List[string]]::new()
    }

    $patch = $null
    try {
        $patch = ConvertFrom-Json -InputObject $JsonPayload -ErrorAction Stop
    }
    catch {
        Add-GenerationGateAppJsonV1Error -Result $result -Message 'Parse Error: Unable to parse JSON patch. Output must be raw JSON without Markdown fences.'
        return $result
    }

    $allowedProperties = @('append_pages')
    foreach ($prop in $patch.PSObject.Properties) {
        if ($allowedProperties -notcontains $prop.Name) {
            Add-GenerationGateAppJsonV1Error -Result $result -Message "Security Violation: Patch contains forbidden field '$($prop.Name)'. Only append_pages is allowed in V1." -Hard
        }
    }

    if ($null -eq $patch.append_pages) {
        Add-GenerationGateAppJsonV1Error -Result $result -Message "Schema Error: V1 requires an 'append_pages' field."
        return $result
    }

    if ($patch.append_pages -isnot [System.Collections.IEnumerable] -or $patch.append_pages -is [string]) {
        Add-GenerationGateAppJsonV1Error -Result $result -Message "Schema Error: 'append_pages' must be an array of page paths."
        return $result
    }

    foreach ($pagePath in @($patch.append_pages)) {
        $pagePathString = [string]$pagePath
        if ([string]::IsNullOrWhiteSpace($pagePathString)) {
            Add-GenerationGateAppJsonV1Error -Result $result -Message "Schema Error: append_pages entries must be non-empty strings."
            continue
        }

        if ($pagePathString -notmatch '^pages/[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$') {
            Add-GenerationGateAppJsonV1Error -Result $result -Message "Path Error: '$pagePathString' must match pages/<name>/<name> with no file extension."
            continue
        }

        $physicalPath = Join-Path $TargetWorkspace ($pagePathString -replace '/', '\')
        $wxmlPath = "$physicalPath.wxml"
        if (-not (Test-Path $wxmlPath)) {
            Add-GenerationGateAppJsonV1Error -Result $result -Message "Logic Error: Page '$pagePathString' does not exist on disk at '$wxmlPath'. Only real generated pages may be registered."
        }
    }

    return $result
}

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Payload')]
    [string]$JsonPayload,

    [Parameter(Mandatory = $true, ParameterSetName = 'File')]
    [string]$JsonFilePath,

    [Parameter(Mandatory = $false)]
    [string]$TargetWorkspace = (Get-Location).Path
)

if ($PSCmdlet.ParameterSetName -eq 'File') {
    if (-not (Test-Path $JsonFilePath)) {
        throw "Fatal: JSON patch file not found: $JsonFilePath"
    }

    $JsonPayload = Get-Content -Path $JsonFilePath -Raw -Encoding UTF8
}

$gateScript = Join-Path $PSScriptRoot 'generation-gate-app-json-v1.ps1'
if (-not (Test-Path $gateScript)) {
    throw "Fatal: App Json Gate script not found: $gateScript"
}
. $gateScript

function Join-GenerationGateAppJsonMessages {
    param([Parameter(Mandatory)][System.Collections.Generic.List[string]]$Errors)

    return (($Errors | ForEach-Object { "- $_" }) -join [Environment]::NewLine)
}

function Write-Utf8NoBomFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

$checkResult = Invoke-GenerationGateAppJsonV1 -JsonPayload $JsonPayload -TargetWorkspace $TargetWorkspace

switch ($checkResult.Status) {
    'pass' {
        $appJsonPath = Join-Path $TargetWorkspace 'app.json'
        if (-not (Test-Path $appJsonPath)) {
            [Console]::Error.WriteLine("[FATAL APP.JSON MISSING] app.json was not found in the target workspace.")
            exit 2
        }

        $appJsonObject = ConvertFrom-Json -InputObject (Get-Content -Path $appJsonPath -Raw -Encoding UTF8) -ErrorAction Stop
        $patch = ConvertFrom-Json -InputObject $JsonPayload -ErrorAction Stop
        $pagesToAdd = @($patch.append_pages)

        if ($null -eq $appJsonObject.pages) {
            $appJsonObject | Add-Member -MemberType NoteProperty -Name 'pages' -Value @()
        }

        $existingPages = @($appJsonObject.pages)
        $addedPages = New-Object System.Collections.Generic.List[string]

        foreach ($pagePath in $pagesToAdd) {
            $pagePathString = [string]$pagePath
            if ($existingPages -notcontains $pagePathString) {
                $existingPages += $pagePathString
                $addedPages.Add($pagePathString)
                Write-Host "Registered page: $pagePathString"
            }
            else {
                Write-Host "Skipped existing page: $pagePathString"
            }
        }

        $appJsonObject.pages = $existingPages
        $mergedJson = ConvertTo-Json -InputObject $appJsonObject -Depth 20
        Write-Utf8NoBomFile -Path $appJsonPath -Content $mergedJson

        return [pscustomobject]@{
            status = 'success'
            target_workspace = $TargetWorkspace
            added_pages = @($addedPages)
            total_pages = @($existingPages).Count
        }
    }
    'retryable_fail' {
        $errorText = Join-GenerationGateAppJsonMessages -Errors $checkResult.Errors
        $retryPrompt = @"
[PATCH REJECTED]
Your JSON app.json patch failed validation. Fix the exact errors below and return the updated JSON patch.

ERRORS:
$errorText

INSTRUCTIONS FOR RETRY:
1. Do not apologize or explain.
2. Return ONLY a JSON object with append_pages.
3. Use page paths like "pages/home/index" with no file extension.
"@
        [Console]::Error.WriteLine($retryPrompt)
        exit 1
    }
    'hard_fail' {
        $errorText = Join-GenerationGateAppJsonMessages -Errors $checkResult.Errors
        $fatalPrompt = @"
[FATAL APP.JSON PATCH VIOLATION]
You attempted to modify app.json outside the V1 append_pages contract.

ERRORS:
$errorText

ACTION:
The operation has been aborted. DO NOT RETRY this patch shape.
"@
        [Console]::Error.WriteLine($fatalPrompt)
        exit 2
    }
    default {
        [Console]::Error.WriteLine("[UNKNOWN APP.JSON GATE STATUS] Unsupported gate status: $($checkResult.Status)")
        exit 3
    }
}

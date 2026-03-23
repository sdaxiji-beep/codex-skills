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
        throw "Fatal: JSON payload file not found: $JsonFilePath"
    }

    $JsonPayload = Get-Content -Path $JsonFilePath -Raw -Encoding UTF8
}

$gateScript = Join-Path $PSScriptRoot 'generation-gate-v1.ps1'
if (-not (Test-Path $gateScript)) {
    throw "Fatal: Generation Gate script not found: $gateScript"
}
. $gateScript

function Join-GenerationGateMessages {
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

$checkResult = Invoke-GenerationGateV1 -JsonPayload $JsonPayload -TargetWorkspace $TargetWorkspace

switch ($checkResult.Status) {
    'pass' {
        $bundle = ConvertFrom-Json -InputObject $JsonPayload -ErrorAction Stop
        $writtenFiles = New-Object System.Collections.Generic.List[string]

        foreach ($file in @($bundle.files)) {
            $relativePath = [string]$file.path
            $fullPath = Join-Path $TargetWorkspace $relativePath
            $dirPath = Split-Path $fullPath -Parent

            if (-not (Test-Path $dirPath)) {
                New-Item -ItemType Directory -Path $dirPath -Force | Out-Null
            }

            Write-Utf8NoBomFile -Path $fullPath -Content ([string]$file.content)
            $writtenFiles.Add($relativePath)
            Write-Host "Wrote: $relativePath"
        }

        return [pscustomobject]@{
            status = 'success'
            target_workspace = $TargetWorkspace
            written_files = @($writtenFiles)
        }
    }
    'retryable_fail' {
        $errorText = Join-GenerationGateMessages -Errors $checkResult.Errors
        $retryPrompt = @"
[GENERATION REJECTED]
Your generated JSON bundle failed validation. You MUST fix the following errors and regenerate the entire JSON bundle:

ERRORS:
$errorText

INSTRUCTIONS FOR RETRY:
1. Do not apologize or explain.
2. Fix all the exact errors listed above.
3. Return ONLY the corrected valid JSON object. No markdown formatting outside the JSON, no extra conversational text.
"@
        [Console]::Error.WriteLine($retryPrompt)
        exit 1
    }
    'hard_fail' {
        $errorText = Join-GenerationGateMessages -Errors $checkResult.Errors
        $fatalPrompt = @"
[FATAL BOUNDARY VIOLATION]
You attempted to write to globally forbidden files or step outside the page sandbox.
This is strictly prohibited in V1.

ERRORS:
$errorText

ACTION:
The operation has been aborted. DO NOT RETRY this specific file path.
"@
        [Console]::Error.WriteLine($fatalPrompt)
        exit 2
    }
    default {
        [Console]::Error.WriteLine("[UNKNOWN GATE STATUS] Unsupported gate status: $($checkResult.Status)")
        exit 3
    }
}

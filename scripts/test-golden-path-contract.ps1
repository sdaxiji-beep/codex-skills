param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"
. "$PSScriptRoot\wechat.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$goldenPathDoc = Join-Path $repoRoot 'GOLDEN_PATH.md'
$phasePlanDoc = Join-Path $repoRoot 'PHASE_PLAN.md'

$requiredDocs = @($goldenPathDoc, $phasePlanDoc)
$missingDocs = @($requiredDocs | Where-Object { -not (Test-Path $_) })

$requiredCommands = @(
    'Invoke-WechatCreate',
    'Invoke-WechatGenerateComponent',
    'Invoke-WechatGeneratePage',
    'Invoke-WechatPatchAppJson',
    'Invoke-GeneratedProjectPreview',
    'Invoke-GeneratedProjectDeployGuard'
)

$commandChecks = @(
    foreach ($name in $requiredCommands) {
        [pscustomobject]@{
            name   = $name
            exists = ((Get-Command $name -ErrorAction SilentlyContinue) -ne $null)
        }
    }
)

$missingCommands = @($commandChecks | Where-Object { -not $_.exists } | ForEach-Object { $_.name })

$docPatterns = @(
    'component generation',
    'page generation',
    'app\.json',
    'preview guard',
    'upload/deploy guard'
)

$docPatternChecks = @()
if (Test-Path $goldenPathDoc) {
    $content = Get-Content $goldenPathDoc -Raw
    $docPatternChecks = @(
        foreach ($pattern in $docPatterns) {
            [pscustomobject]@{
                pattern = $pattern
                exists  = [bool]($content -match $pattern)
            }
        }
    )
}

$missingPatterns = @($docPatternChecks | Where-Object { -not $_.exists } | ForEach-Object { $_.pattern })

$pass = ($missingDocs.Count -eq 0) -and ($missingCommands.Count -eq 0) -and ($missingPatterns.Count -eq 0)
$status = if ($pass) { 'ready' } else { 'blocked' }

New-TestResult -Name 'golden-path-contract' -Data @{
    pass             = $pass
    exit_code        = if ($pass) { 0 } else { 1 }
    status           = $status
    required_docs    = $requiredDocs
    missing_docs     = $missingDocs
    command_checks   = $commandChecks
    missing_commands = $missingCommands
    missing_patterns = $missingPatterns
}


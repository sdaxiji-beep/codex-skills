[CmdletBinding()]
param(
    [string]$RepoRoot = ''
)

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
}

$manifestPath = Join-Path $RepoRoot 'release-package.manifest.json'
if (-not (Test-Path $manifestPath)) {
    throw "release package manifest not found: $manifestPath"
}

$manifest = Get-Content -Path $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$gitignorePath = Join-Path $RepoRoot '.gitignore'
$gitignore = if (Test-Path $gitignorePath) {
    Get-Content -Path $gitignorePath -Raw -Encoding UTF8
} else {
    ''
}

$missingIncludes = @()
$includedFiles = @()
foreach ($entry in @($manifest.include)) {
    $fullPath = Join-Path $RepoRoot $entry
    if (-not (Test-Path $fullPath)) {
        $missingIncludes += $entry
        continue
    }

    $item = Get-Item $fullPath
    if ($item.PSIsContainer) {
        $includedFiles += @(Get-ChildItem -Path $fullPath -Recurse -File | ForEach-Object { $_.FullName })
    }
    else {
        $includedFiles += $item.FullName
    }
}

$missingExcludeRules = @()
foreach ($entry in @($manifest.exclude)) {
    if ($gitignore -notmatch [regex]::Escape($entry)) {
        $missingExcludeRules += $entry
    }
}

$releaseDocPath = Join-Path $RepoRoot 'RELEASE_PACKAGE.md'
$releaseDoc = if (Test-Path $releaseDocPath) {
    Get-Content -Path $releaseDocPath -Raw -Encoding UTF8
} else {
    ''
}

$missingDocMentions = @()
foreach ($entry in @($manifest.exclude)) {
    if ($releaseDoc -notmatch [regex]::Escape($entry)) {
        $missingDocMentions += $entry
    }
}

$blockedFilesPresent = @()
$rootDeployConfig = Join-Path $RepoRoot 'deploy-config.json'
if (Test-Path $rootDeployConfig) {
    $blockedFilesPresent += 'deploy-config.json'
}

$hygieneFindings = @()
$hygienePatterns = @(
    @{ name = 'rooted_g_drive_path'; regex = 'G:\\\\' },
    @{ name = 'rooted_d_drive_path'; regex = 'D:\\\\' },
    @{ name = 'user_profile_path'; regex = 'C:\\\\Users\\\\' },
    @{ name = 'repo_named_path'; regex = 'codex专属' }
)
foreach ($pattern in $hygienePatterns) {
    $matches = Select-String -Path $includedFiles -Pattern $pattern.regex
    foreach ($match in @($matches)) {
        if ($match.Path -eq $PSCommandPath) {
            continue
        }
        $hygieneFindings += ('{0}:{1}:{2}' -f $pattern.name, $match.Path, $match.LineNumber)
    }
}

[pscustomobject]@{
    version = [string]$manifest.version
    pass = (
        $missingIncludes.Count -eq 0 -and
        $missingExcludeRules.Count -eq 0 -and
        $missingDocMentions.Count -eq 0 -and
        $blockedFilesPresent.Count -eq 0 -and
        $hygieneFindings.Count -eq 0
    )
    missing_includes = @($missingIncludes)
    missing_exclude_rules = @($missingExcludeRules)
    missing_doc_mentions = @($missingDocMentions)
    blocked_files_present = @($blockedFilesPresent)
    hygiene_findings = @($hygieneFindings)
}

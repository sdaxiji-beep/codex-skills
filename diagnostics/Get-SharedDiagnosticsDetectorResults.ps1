. "$PSScriptRoot\..\scripts\Write-AtomicJsonCache.ps1"
. "$PSScriptRoot\Invoke-DetectorBridge.ps1"
. "$PSScriptRoot\Invoke-DetectorRound.ps1"
. "$PSScriptRoot\Invoke-RepairLoopDryRun.ps1"

function Get-DiagnosticsCacheFingerprint {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Paths
  )

  $entries = foreach ($path in ($Paths | Sort-Object -Unique)) {
    if (-not (Test-Path $path)) {
      continue
    }

    $item = Get-Item $path -ErrorAction SilentlyContinue
    if ($null -eq $item -or $item.PSIsContainer) {
      continue
    }

    '{0}|{1}' -f $item.FullName.ToLowerInvariant(), $item.LastWriteTimeUtc.Ticks
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

function Read-SharedDiagnosticsObject {
  param(
    [Parameter(Mandatory = $true)][string]$CachePath,
    [Parameter(Mandatory = $true)][string]$Fingerprint,
    [int]$TtlSeconds = 900
  )

  if (-not (Test-Path $CachePath)) {
    return $null
  }

  try {
    $cached = Get-Content -Path $CachePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
    $generatedAt = Get-Date ([string]$cached.generated_at)
    if (
      $cached.fingerprint -eq $Fingerprint -and
      $null -ne $cached.result -and
      ((Get-Date) - $generatedAt).TotalSeconds -lt $TtlSeconds
    ) {
      return $cached.result
    }
  }
  catch {
  }

  return $null
}

function Write-SharedDiagnosticsObject {
  param(
    [Parameter(Mandatory = $true)][string]$CachePath,
    [Parameter(Mandatory = $true)][string]$Fingerprint,
    [Parameter(Mandatory = $true)]$Result
  )

  $payload = [pscustomobject]@{
    fingerprint = $Fingerprint
    generated_at = (Get-Date).ToString('o')
    result = $Result
  }

  Write-AtomicJsonCache -Path $CachePath -InputObject $payload -Depth 16
}

function Get-SharedDetectorBridgeResult {
  param(
    [Parameter(Mandatory = $true)][string]$PagePath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$PreferredDetector = 'automator',
    [string]$RepoRoot = ''
  )

  if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
  }

  $artifactDir = Join-Path $RepoRoot 'artifacts\wechat-devtools\diagnostics'
  $cachePath = Join-Path $artifactDir 'shared-detector-bridge-cache.json'
  $fingerprint = Get-DiagnosticsCacheFingerprint -Paths @(
    (Join-Path $RepoRoot 'diagnostics\Invoke-DetectorBridge.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-AutomatorCheck.ps1'),
    (Join-Path $RepoRoot 'diagnostics\screenshot\Invoke-ScreenshotFallback.ps1'),
    (Join-Path $RepoRoot 'diagnostics\New-PageIssue.ps1'),
    (Join-Path $RepoRoot 'scripts\probe-automator.js')
  )

  $cached = Read-SharedDiagnosticsObject -CachePath $cachePath -Fingerprint $fingerprint
  if ($null -ne $cached) {
    return $cached
  }

  New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
  $result = Invoke-DetectorBridge -PagePath $PagePath -ProjectPath $ProjectPath -PreferredDetector $PreferredDetector
  Write-SharedDiagnosticsObject -CachePath $cachePath -Fingerprint $fingerprint -Result $result
  return $result
}

function Get-SharedDetectorRoundResult {
  param(
    [Parameter(Mandatory = $true)][string]$PagePath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [string]$PreferredDetector = 'automator',
    [double]$RepairConfidenceThreshold = 0.50,
    [bool]$EnforcePageRecognition = $true,
    [switch]$CollectConsoleLog,
    [string]$RepoRoot = ''
  )

  if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
  }

  $artifactDir = Join-Path $RepoRoot 'artifacts\wechat-devtools\diagnostics'
  $cachePath = Join-Path $artifactDir 'shared-detector-round-cache.json'
  $fingerprint = Get-DiagnosticsCacheFingerprint -Paths @(
    (Join-Path $RepoRoot 'diagnostics\Invoke-DetectorRound.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-DetectorBridge.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-AutomatorCheck.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-ProjectHealthOverlay.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-CompileHealthOverlay.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-ConsoleErrorOverlay.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-DetectorDecision.ps1'),
    (Join-Path $RepoRoot 'diagnostics\screenshot\Invoke-ScreenshotFallback.ps1'),
    (Join-Path $RepoRoot 'diagnostics\New-PageIssue.ps1'),
    (Join-Path $RepoRoot 'scripts\probe-automator.js')
  )

  $cached = Read-SharedDiagnosticsObject -CachePath $cachePath -Fingerprint $fingerprint
  if ($null -ne $cached) {
    return $cached
  }

  New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
  $result = Invoke-DetectorRound `
    -PagePath $PagePath `
    -ProjectPath $ProjectPath `
    -PreferredDetector $PreferredDetector `
    -RepairConfidenceThreshold $RepairConfidenceThreshold `
    -EnforcePageRecognition $EnforcePageRecognition `
    -CollectConsoleLog:$CollectConsoleLog
  Write-SharedDiagnosticsObject -CachePath $cachePath -Fingerprint $fingerprint -Result $result
  return $result
}

function Get-SharedRepairLoopDryRunResult {
  param(
    [Parameter(Mandatory = $true)][string]$PagePath,
    [Parameter(Mandatory = $true)][string]$ProjectPath,
    [int]$MaxRounds = 1,
    [double]$RepairConfidenceThreshold = 0.50,
    [bool]$StopOnDuplicateIssue = $true,
    [string]$RepoRoot = ''
  )

  if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
  }

  $artifactDir = Join-Path $RepoRoot 'artifacts\wechat-devtools\diagnostics'
  $cachePath = Join-Path $artifactDir 'shared-repairloop-dryrun-cache.json'
  $fingerprint = Get-DiagnosticsCacheFingerprint -Paths @(
    (Join-Path $RepoRoot 'diagnostics\Invoke-RepairLoopDryRun.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-DetectorRound.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-RepairStub.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-RepairActionGuard.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-DetectorBridge.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-AutomatorCheck.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-DetectorDecision.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-ProjectHealthOverlay.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-CompileHealthOverlay.ps1'),
    (Join-Path $RepoRoot 'diagnostics\Invoke-ConsoleErrorOverlay.ps1'),
    (Join-Path $RepoRoot 'diagnostics\screenshot\Invoke-ScreenshotFallback.ps1'),
    (Join-Path $RepoRoot 'diagnostics\New-PageIssue.ps1'),
    (Join-Path $RepoRoot 'scripts\probe-automator.js')
  )

  $cached = Read-SharedDiagnosticsObject -CachePath $cachePath -Fingerprint $fingerprint
  if ($null -ne $cached) {
    return $cached
  }

  New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
  $result = Invoke-RepairLoopDryRun `
    -PagePath $PagePath `
    -ProjectPath $ProjectPath `
    -MaxRounds $MaxRounds `
    -RepairConfidenceThreshold $RepairConfidenceThreshold `
    -StopOnDuplicateIssue:$StopOnDuplicateIssue
  Write-SharedDiagnosticsObject -CachePath $cachePath -Fingerprint $fingerprint -Result $result
  return $result
}

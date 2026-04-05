$ErrorActionPreference = "Stop"

function New-AuditFinding {
  param(
    [string]$Severity,
    [string]$Category,
    [string]$File,
    [string]$Message,
    [int]$LineNumber = 0
  )

  [pscustomobject]@{
    severity = $Severity
    category = $Category
    file = $File
    line = $LineNumber
    message = $Message
  }
}

function Get-RepoRoot {
  return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

function Get-ReleasePackageSurface {
  param([string]$RepoRoot)

  $output = & npm pack --dry-run --json 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($output)) {
    throw "npm pack --dry-run --json failed."
  }

  $packInfo = $output | ConvertFrom-Json
  if ($packInfo -is [array]) {
    $packInfo = $packInfo[0]
  }

  $files = @()
  foreach ($entry in $packInfo.files) {
    $path = Join-Path $RepoRoot $entry.path
    $files += [pscustomobject]@{
      relative_path = $entry.path
      full_path = $path
      size = $entry.size
    }
  }

  [pscustomobject]@{
    metadata = $packInfo
    files = $files
  }
}

function Test-AbsolutePathLeakage {
  param(
    [string]$RepoRoot,
    [object[]]$PackageFiles
  )

  $findings = New-Object System.Collections.Generic.List[object]
  $criticalPatterns = @(
    'G:\\codex专属',
    'D:\\卤味',
    'C:\\Users\\',
    'C:\\Program Files'
  )

  foreach ($file in $PackageFiles) {
    if (-not (Test-Path -LiteralPath $file.full_path)) {
      continue
    }

    if ($file.relative_path -eq "scripts/test-deep-release-audit.ps1") {
      continue
    }

    $matches = Select-String -Path $file.full_path -Pattern $criticalPatterns -SimpleMatch
    foreach ($match in $matches) {
      $findings.Add((New-AuditFinding -Severity "critical" -Category "absolute_path_leak" -File $file.relative_path -LineNumber $match.LineNumber -Message $match.Line.Trim()))
    }
  }

  $localOnlyFiles = @("AGENTS.md", "PROJECT_STATE.md")
  foreach ($name in $localOnlyFiles) {
    $path = Join-Path $RepoRoot $name
    if (-not (Test-Path -LiteralPath $path)) {
      continue
    }
    $matches = Select-String -Path $path -Pattern $criticalPatterns -SimpleMatch
    foreach ($match in $matches) {
      $findings.Add((New-AuditFinding -Severity "info" -Category "local_only_absolute_path" -File $name -LineNumber $match.LineNumber -Message $match.Line.Trim()))
    }
  }

  return $findings
}

function Test-RegistryIntegrity {
  param([string]$RepoRoot)

  $validatorPath = Join-Path $RepoRoot "scripts\wechat-asset-registry-validator.ps1"
  try {
    $validatorResult = & $validatorPath
  } catch {
    return [pscustomobject]@{
      status = "fail"
      details = $_.Exception.Message
    }
  }

  $migrationTestPath = Join-Path $RepoRoot "scripts\test-asset-registry-migration.ps1"
  try {
    $migrationResult = & $migrationTestPath
  } catch {
    return [pscustomobject]@{
      status = "fail"
      details = $_.Exception.Message
    }
  }

  [pscustomobject]@{
    status = "pass"
    details = @(
      "wechat-asset-registry-validator.ps1: pass",
      "test-asset-registry-migration.ps1: pass"
    )
  }
}

function Test-DocDrift {
  param([string]$RepoRoot)

  $findings = New-Object System.Collections.Generic.List[object]
  $wechatEntrypoint = Join-Path $RepoRoot "scripts\wechat.ps1"
  . $wechatEntrypoint

  $commandNames = @(
    "Invoke-WechatBootstrap",
    "Invoke-WechatDoctor",
    "Invoke-WechatCreate",
    "Get-GeneratedProjectList",
    "Invoke-GeneratedProjectOpen",
    "Invoke-GeneratedProjectPreview",
    "Invoke-GeneratedProjectDeployGuard",
    "Invoke-GeneratedProjectSetAppId",
    "Invoke-GeneratedProjectUpload"
  )

  foreach ($name in $commandNames) {
    if (-not (Get-Command -Name $name -ErrorAction SilentlyContinue)) {
      $findings.Add((New-AuditFinding -Severity "critical" -Category "doc_drift_command_missing" -File "README.md" -Message "Referenced command '$name' is not available after dot-sourcing scripts\\wechat.ps1."))
    }
  }

  $requiredPaths = @(
    "schemas\wechat-task-spec.schema.json",
    "schemas\wechat-page-bundle.schema.json",
    "schemas\wechat-component-bundle.schema.json",
    "schemas\wechat-asset-registry.schema.json",
    "scripts\wechat-task-spec.ps1",
    "scripts\wechat-task-translator.ps1",
    "scripts\wechat-task-bundle-compiler.ps1",
    "scripts\wechat-task-executor.ps1",
    "scripts\wechat-acceptance-checks.ps1",
    "scripts\wechat-acceptance-repair-loop.ps1",
    "scripts\wechat-asset-registry-validator.ps1",
    "scripts\wechat-mcp-tool-boundary.ps1"
  )

  foreach ($relativePath in $requiredPaths) {
    $fullPath = Join-Path $RepoRoot $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
      $findings.Add((New-AuditFinding -Severity "critical" -Category "doc_drift_missing_path" -File "AI_WORKBOOK.md" -Message "Referenced path '$relativePath' does not exist."))
    }
  }

  return $findings
}

function Test-DependencyAndIgnoreState {
  param([string]$RepoRoot)

  $findings = New-Object System.Collections.Generic.List[object]

  $packageJson = Get-Content (Join-Path $RepoRoot "package.json") -Raw | ConvertFrom-Json
  $lockHead = Get-Content (Join-Path $RepoRoot "package-lock.json") -TotalCount 12
  $rootVersionLine = ($lockHead | Select-String '"version":').Line | Select-Object -First 1
  $packageRootVersionLine = ($lockHead | Select-String '^\s+"version":').Line | Select-Object -Last 1

  if ($rootVersionLine -notmatch [regex]::Escape($packageJson.version) -or $packageRootVersionLine -notmatch [regex]::Escape($packageJson.version)) {
    $findings.Add((New-AuditFinding -Severity "critical" -Category "package_lock_drift" -File "package-lock.json" -Message "Root version does not match package.json version '$($packageJson.version)'." ))
  }

  $ignoreFiles = @(".gitignore", ".npmignore")
  foreach ($ignoreFile in $ignoreFiles) {
    $content = Get-Content (Join-Path $RepoRoot $ignoreFile) -Raw
    foreach ($requiredEntry in @("node_modules/", "artifacts/")) {
      if ($content -notmatch [regex]::Escape($requiredEntry)) {
        $findings.Add((New-AuditFinding -Severity "critical" -Category "ignore_rule_missing" -File $ignoreFile -Message "Missing ignore rule '$requiredEntry'." ))
      }
    }
  }

  return $findings
}

function New-AuditReport {
  param(
    [string]$RepoRoot,
    [object]$PackageSurface,
    [object[]]$LeakageFindings,
    [object]$RegistryResult,
    [object[]]$DocFindings,
    [object[]]$DependencyFindings
  )

  $allFindings = @($LeakageFindings + $DocFindings + $DependencyFindings)
  $criticalFindings = @($allFindings | Where-Object { $_.severity -eq "critical" })

  [pscustomobject]@{
    status = if ($criticalFindings.Count -eq 0 -and $RegistryResult.status -eq "pass") { "pass" } else { "fail" }
    generated_at = (Get-Date).ToString("s")
    package = [pscustomobject]@{
      name = $PackageSurface.metadata.name
      version = $PackageSurface.metadata.version
      size = $PackageSurface.metadata.size
      unpackedSize = $PackageSurface.metadata.unpackedSize
      entryCount = $PackageSurface.metadata.entryCount
    }
    checks = [pscustomobject]@{
      absolute_path_leakage = @{
        critical = @($LeakageFindings | Where-Object { $_.severity -eq "critical" })
        informational = @($LeakageFindings | Where-Object { $_.severity -ne "critical" })
      }
      registry_integrity = $RegistryResult
      doc_drift = @($DocFindings)
      dependency_and_ignore_state = @($DependencyFindings)
    }
  }
}

$repoRoot = Get-RepoRoot
$auditDir = Join-Path $repoRoot "artifacts\release-audit"
New-Item -ItemType Directory -Path $auditDir -Force | Out-Null

$packageSurface = Get-ReleasePackageSurface -RepoRoot $repoRoot
$leakageFindings = Test-AbsolutePathLeakage -RepoRoot $repoRoot -PackageFiles $packageSurface.files
$registryResult = Test-RegistryIntegrity -RepoRoot $repoRoot
$docFindings = Test-DocDrift -RepoRoot $repoRoot
$dependencyFindings = Test-DependencyAndIgnoreState -RepoRoot $repoRoot

$report = New-AuditReport -RepoRoot $repoRoot -PackageSurface $packageSurface -LeakageFindings $leakageFindings -RegistryResult $registryResult -DocFindings $docFindings -DependencyFindings $dependencyFindings

$jsonPath = Join-Path $auditDir "deep-release-audit-latest.json"
$txtPath = Join-Path $auditDir "deep-release-audit-latest.txt"

$report | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding UTF8

$textLines = New-Object System.Collections.Generic.List[string]
$textLines.Add("Deep Release Audit")
$textLines.Add("Status: $($report.status)")
$textLines.Add("Generated: $($report.generated_at)")
$textLines.Add("")
$textLines.Add("Package")
$textLines.Add("  name: $($report.package.name)")
$textLines.Add("  version: $($report.package.version)")
$textLines.Add("  size: $($report.package.size)")
$textLines.Add("  unpackedSize: $($report.package.unpackedSize)")
$textLines.Add("  entryCount: $($report.package.entryCount)")
$textLines.Add("")

foreach ($sectionName in @("absolute_path_leakage", "doc_drift", "dependency_and_ignore_state")) {
  $textLines.Add($sectionName)
  $section = $report.checks.$sectionName
  if ($sectionName -eq "absolute_path_leakage") {
    foreach ($finding in @($section.critical + $section.informational)) {
      $textLines.Add("  [$($finding.severity)] $($finding.file):$($finding.line) $($finding.message)")
    }
    if ((@($section.critical + $section.informational)).Count -eq 0) {
      $textLines.Add("  none")
    }
  } else {
    foreach ($finding in @($section)) {
      $textLines.Add("  [$($finding.severity)] $($finding.file):$($finding.line) $($finding.message)")
    }
    if ((@($section)).Count -eq 0) {
      $textLines.Add("  none")
    }
  }
  $textLines.Add("")
}

$textLines.Add("registry_integrity")
$textLines.Add("  status: $($report.checks.registry_integrity.status)")
foreach ($detail in @($report.checks.registry_integrity.details)) {
  $textLines.Add("  $detail")
}
$textLines | Set-Content -Path $txtPath -Encoding UTF8

$report
if ($report.status -ne "pass") {
  exit 1
}

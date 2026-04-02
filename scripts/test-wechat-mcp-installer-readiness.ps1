$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent

function Assert-Contains {
  param(
    [string]$Text,
    [string]$Pattern,
    [string]$Label
  )

  if ($Text -notmatch $Pattern) {
    throw "$Label missing pattern: $Pattern"
  }
}

function Assert-NoRootedPath {
  param(
    [string]$Text,
    [string]$Label
  )

  if ($Text -match '(?m)^[A-Za-z]:\\|^[A-Za-z]:/') {
    throw "$Label contains a rooted path"
  }
}

Write-Host "[test] start installer readiness verification..." -ForegroundColor Cyan

$registryDocPath = Join-Path $repoRoot 'MCP_REGISTRY_READINESS.md'
$surfaceMapPath = Join-Path $repoRoot 'MCP_SURFACE_MAP.md'
$clientUsagePath = Join-Path $repoRoot 'MCP_CLIENT_USAGE.md'
$inspectorPath = Join-Path $repoRoot 'MCP_INSPECTOR_QUICKSTART.md'
$serverJsonPath = Join-Path $repoRoot 'server.json'
$packageJsonPath = Join-Path $repoRoot 'package.json'
$serverScriptPath = Join-Path $repoRoot 'scripts\wechat-mcp-server.mjs'

$registryDoc = Get-Content $registryDocPath -Raw
$surfaceMap = Get-Content $surfaceMapPath -Raw
$clientUsage = Get-Content $clientUsagePath -Raw
$inspector = Get-Content $inspectorPath -Raw
$serverJson = Get-Content $serverJsonPath -Raw | ConvertFrom-Json
$packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
$serverScript = Get-Content $serverScriptPath -Raw

Assert-Contains $registryDoc 'installer-facing' 'MCP_REGISTRY_READINESS.md'
Assert-Contains $registryDoc 'wechat://installer-readiness' 'MCP_REGISTRY_READINESS.md'
Assert-Contains $registryDoc 'server.json' 'MCP_REGISTRY_READINESS.md'
Assert-Contains $registryDoc 'mcpName' 'MCP_REGISTRY_READINESS.md'
Assert-Contains $registryDoc 'scripts/wechat-mcp-server.mjs' 'MCP_REGISTRY_READINESS.md'
Assert-Contains $registryDoc 'repo-relative' 'MCP_REGISTRY_READINESS.md'
Assert-Contains $registryDoc 'machine-neutral' 'MCP_REGISTRY_READINESS.md'
Assert-NoRootedPath $registryDoc 'MCP_REGISTRY_READINESS.md'

Assert-Contains $surfaceMap 'wechat://installer-readiness' 'MCP_SURFACE_MAP.md'
Assert-Contains $surfaceMap 'MCP_REGISTRY_READINESS.md' 'MCP_SURFACE_MAP.md'
Assert-NoRootedPath $surfaceMap 'MCP_SURFACE_MAP.md'

Assert-Contains $clientUsage 'wechat://installer-readiness' 'MCP_CLIENT_USAGE.md'
Assert-NoRootedPath $clientUsage 'MCP_CLIENT_USAGE.md'

Assert-Contains $inspector 'wechat://installer-readiness' 'MCP_INSPECTOR_QUICKSTART.md'
Assert-NoRootedPath $inspector 'MCP_INSPECTOR_QUICKSTART.md'

$serverResourceNames = @($serverJson.resources)
if ($serverResourceNames -notcontains 'installer_readiness') {
  throw 'server.json missing installer_readiness resource'
}

if (-not $packageJson.scripts.'mcp:installer-readiness') {
  throw 'package.json missing mcp:installer-readiness script'
}

Assert-Contains $serverScript 'installer_readiness' 'scripts/wechat-mcp-server.mjs'
Assert-Contains $serverScript 'wechat://installer-readiness' 'scripts/wechat-mcp-server.mjs'

Write-Host "[test] PASS: installer readiness surface is public-safe and repo-relative" -ForegroundColor Green

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

Write-Host "[test] start distribution quickstart verification..." -ForegroundColor Cyan

$docPath = Join-Path $repoRoot 'MCP_DISTRIBUTION_QUICKSTART.md'
$surfaceMapPath = Join-Path $repoRoot 'MCP_SURFACE_MAP.md'
$serverJsonPath = Join-Path $repoRoot 'server.json'
$serverScriptPath = Join-Path $repoRoot 'scripts\wechat-mcp-server.mjs'

$doc = Get-Content $docPath -Raw
$surfaceMap = Get-Content $surfaceMapPath -Raw
$serverJson = Get-Content $serverJsonPath -Raw | ConvertFrom-Json
$serverScript = Get-Content $serverScriptPath -Raw

Assert-Contains $doc 'installer-facing' 'MCP_DISTRIBUTION_QUICKSTART.md'
Assert-Contains $doc 'consumer-facing' 'MCP_DISTRIBUTION_QUICKSTART.md'
Assert-Contains $doc 'server.json' 'MCP_DISTRIBUTION_QUICKSTART.md'
Assert-Contains $doc 'wechat://installer-readiness' 'MCP_DISTRIBUTION_QUICKSTART.md'
Assert-Contains $doc 'wechat://registry-readiness' 'MCP_DISTRIBUTION_QUICKSTART.md'
Assert-Contains $doc 'wechat://distribution-quickstart' 'MCP_DISTRIBUTION_QUICKSTART.md'
Assert-Contains $doc 'scripts/wechat-mcp-server.mjs' 'MCP_DISTRIBUTION_QUICKSTART.md'
Assert-NoRootedPath $doc 'MCP_DISTRIBUTION_QUICKSTART.md'

Assert-Contains $surfaceMap 'wechat://distribution-quickstart' 'MCP_SURFACE_MAP.md'
Assert-Contains $surfaceMap 'MCP_DISTRIBUTION_QUICKSTART.md' 'MCP_SURFACE_MAP.md'
Assert-NoRootedPath $surfaceMap 'MCP_SURFACE_MAP.md'

$resourceNames = @($serverJson.resources)
if ($resourceNames -notcontains 'distribution_quickstart') {
  throw 'server.json missing distribution_quickstart resource'
}

Assert-Contains $serverScript 'distribution_quickstart' 'scripts/wechat-mcp-server.mjs'
Assert-Contains $serverScript 'wechat://distribution-quickstart' 'scripts/wechat-mcp-server.mjs'

Write-Host "[test] PASS: distribution quickstart surface is public-safe and repo-relative" -ForegroundColor Green

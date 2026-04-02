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

Write-Host "[test] start registration guidance verification..." -ForegroundColor Cyan

$docPath = Join-Path $repoRoot 'MCP_REGISTRATION_GUIDANCE.md'
$surfaceMapPath = Join-Path $repoRoot 'MCP_SURFACE_MAP.md'
$serverJsonPath = Join-Path $repoRoot 'server.json'
$packageJsonPath = Join-Path $repoRoot 'package.json'
$serverScriptPath = Join-Path $repoRoot 'scripts\wechat-mcp-server.mjs'

$doc = Get-Content $docPath -Raw
$surfaceMap = Get-Content $surfaceMapPath -Raw
$serverJson = Get-Content $serverJsonPath -Raw | ConvertFrom-Json
$packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
$serverScript = Get-Content $serverScriptPath -Raw

Assert-Contains $doc 'clone-agnostic' 'MCP_REGISTRATION_GUIDANCE.md'
Assert-Contains $doc 'installer-facing' 'MCP_REGISTRATION_GUIDANCE.md'
Assert-Contains $doc 'consumer-facing' 'MCP_REGISTRATION_GUIDANCE.md'
Assert-Contains $doc 'server.json' 'MCP_REGISTRATION_GUIDANCE.md'
Assert-Contains $doc 'scripts/wechat-mcp-server.mjs' 'MCP_REGISTRATION_GUIDANCE.md'
Assert-Contains $doc 'wechat://registration-guidance' 'MCP_REGISTRATION_GUIDANCE.md'
Assert-Contains $doc 'wechat://installer-readiness' 'MCP_REGISTRATION_GUIDANCE.md'
Assert-Contains $doc 'wechat://registry-readiness' 'MCP_REGISTRATION_GUIDANCE.md'
Assert-NoRootedPath $doc 'MCP_REGISTRATION_GUIDANCE.md'

Assert-Contains $surfaceMap 'wechat://registration-guidance' 'MCP_SURFACE_MAP.md'
Assert-Contains $surfaceMap 'MCP_REGISTRATION_GUIDANCE.md' 'MCP_SURFACE_MAP.md'
Assert-NoRootedPath $surfaceMap 'MCP_SURFACE_MAP.md'

$serverResourceNames = @($serverJson.resources)
if ($serverResourceNames -notcontains 'registration_guidance') {
  throw 'server.json missing registration_guidance resource'
}

if (-not $packageJson.scripts.'mcp:registration-guidance') {
  throw 'package.json missing mcp:registration-guidance script'
}

Assert-Contains $serverScript 'registration_guidance' 'scripts/wechat-mcp-server.mjs'
Assert-Contains $serverScript 'wechat://registration-guidance' 'scripts/wechat-mcp-server.mjs'

Write-Host "[test] PASS: registration guidance surface is public-safe and repo-relative" -ForegroundColor Green

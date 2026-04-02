[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$packagePath = Join-Path $repoRoot 'package.json'
$serverPath = Join-Path $repoRoot 'server.json'

$package = Get-Content $packagePath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop
$server = Get-Content $serverPath -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop

$errors = New-Object System.Collections.Generic.List[string]

if ($package.mcpName -ne $server.mcpName) {
  $errors.Add("mcpName mismatch: package=$($package.mcpName) server=$($server.mcpName)")
}

if ($server.name -ne 'wechat-devtools-control-mcp') {
  $errors.Add("Unexpected server name: $($server.name)")
}

if ($server.entry -ne 'scripts/wechat-mcp-server.mjs') {
  $errors.Add("Unexpected server entry: $($server.entry)")
}

if ($server.transport -ne 'stdio') {
  $errors.Add("Unexpected transport: $($server.transport)")
}

if ($server.runtime -ne 'node') {
  $errors.Add("Unexpected runtime: $($server.runtime)")
}

if ($server.registration.notes -match '^[A-Za-z]:\\') {
  $errors.Add('registration.notes should not contain a rooted local path')
}

$requiredTools = @(
  'describe_contract',
  'describe_execution_profile',
  'validate_page_bundle',
  'apply_page_bundle',
  'validate_component_bundle',
  'apply_component_bundle',
  'validate_app_json_patch',
  'apply_app_json_patch'
)

$missingTools = @($requiredTools | Where-Object { $_ -notin $server.tools })
if ($missingTools.Count -gt 0) {
  $errors.Add("Missing tools: $($missingTools -join ', ')")
}

$requiredResources = @(
  'server_inventory',
  'consumer_router',
  'path_conventions',
  'client_usage_guide',
  'inspector_quickstart',
  'surface_map'
)

$missingResources = @($requiredResources | Where-Object { $_ -notin $server.resources })
if ($missingResources.Count -gt 0) {
  $errors.Add("Missing resources: $($missingResources -join ', ')")
}

$requiredPrompts = @(
  'generate_page_bundle',
  'generate_component_bundle',
  'repair_page_issue',
  'patch_app_routes'
)

$missingPrompts = @($requiredPrompts | Where-Object { $_ -notin $server.prompts })
if ($missingPrompts.Count -gt 0) {
  $errors.Add("Missing prompts: $($missingPrompts -join ', ')")
}

$result = [pscustomobject]@{
  test = 'wechat-mcp-distribution-metadata'
  pass = ($errors.Count -eq 0)
  exit_code = $(if ($errors.Count -eq 0) { 0 } else { 1 })
  mcp_name = $server.mcpName
  tools = @($server.tools).Count
  resources = @($server.resources).Count
  prompts = @($server.prompts).Count
  errors = @($errors)
}

$result | ConvertTo-Json -Depth 5
exit $result.exit_code

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$serverPath = Join-Path $PSScriptRoot 'wechat-mcp-server.mjs'

Write-Host '[test] Starting MCP server smoke manifest check...' -ForegroundColor Cyan

$env:WECHAT_MCP_SERVER_SMOKE = 'manifest'
try {
  $output = & node $serverPath 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "wechat-mcp-server.mjs exited with code $LASTEXITCODE`n$output"
  }

  $manifest = $output | ConvertFrom-Json -ErrorAction Stop

  $expectedTools = @(
    'describe_contract',
    'describe_execution_profile',
    'run_task_pipeline',
    'validate_page_bundle',
    'apply_page_bundle',
    'validate_component_bundle',
    'apply_component_bundle',
    'validate_app_json_patch',
    'apply_app_json_patch'
  )

  $expectedPrompts = @(
    'generate_page_bundle',
    'generate_component_bundle',
    'repair_page_issue',
    'patch_app_routes'
  )

  $expectedResources = @(
    'project_state',
    'validation_plan',
    'consumer_router',
    'path_conventions',
    'prompt_selection_guide',
    'latest_diagnostics_metrics',
    'boundary_contract',
    'external_client_entrypoints',
    'release_package',
    'tool_selection_guide',
    'server_inventory',
    'client_usage_guide',
    'inspector_quickstart',
    'surface_map'
  )

  $missingTools = @($expectedTools | Where-Object { $_ -notin $manifest.tools })
  $missingPrompts = @($expectedPrompts | Where-Object { $_ -notin $manifest.prompts })
  $missingResources = @($expectedResources | Where-Object { $_ -notin $manifest.resources })

  if ($manifest.server_name -ne 'wechat-devtools-control-mcp') {
    throw "Unexpected server_name: $($manifest.server_name)"
  }
  if ($manifest.version -ne '1.0.0') {
    throw "Unexpected version: $($manifest.version)"
  }
  if ($manifest.smoke_mode -ne 'manifest') {
    throw "Unexpected smoke_mode: $($manifest.smoke_mode)"
  }
  if ($manifest.boundary_script -ne 'scripts/wechat-mcp-tool-boundary.ps1') {
    throw "Unexpected boundary_script: $($manifest.boundary_script)"
  }
  if ($missingTools.Count -gt 0 -or $missingPrompts.Count -gt 0 -or $missingResources.Count -gt 0) {
    $messages = @('Smoke manifest is missing expected entries:')
    if ($missingTools.Count -gt 0) {
      $messages += "tools: $($missingTools -join ', ')"
    }
    if ($missingPrompts.Count -gt 0) {
      $messages += "prompts: $($missingPrompts -join ', ')"
    }
    if ($missingResources.Count -gt 0) {
      $messages += "resources: $($missingResources -join ', ')"
    }
    throw ($messages -join "`n")
  }

  Write-Host '[test] PASS: MCP smoke manifest is complete' -ForegroundColor Green
  exit 0
}
finally {
  Remove-Item Env:WECHAT_MCP_SERVER_SMOKE -ErrorAction SilentlyContinue
}

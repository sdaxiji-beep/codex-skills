param()

$repoRoot = Split-Path $PSScriptRoot -Parent
$server = Join-Path $repoRoot 'scripts\wechat-mcp-server.mjs'

$env:WECHAT_MCP_SERVER_SMOKE = 'manifest'
try {
    $raw = & node $server 2>&1
    $code = $LASTEXITCODE
}
finally {
    Remove-Item Env:WECHAT_MCP_SERVER_SMOKE -ErrorAction SilentlyContinue
}

$manifest = $null
try {
    $manifest = $raw | ConvertFrom-Json -ErrorAction Stop
}
catch {
    $manifest = $null
}

$pass = (
    $code -eq 0 -and
    $null -ne $manifest -and
    $manifest.server_name -eq 'wechat-devtools-control-mcp' -and
    $manifest.tools -contains 'validate_page_bundle' -and
    $manifest.prompts -contains 'generate_page_bundle' -and
    $manifest.resources -contains 'server_inventory' -and
    $manifest.resources -contains 'tool_selection_guide' -and
    $manifest.resources -contains 'consumer_router' -and
    $manifest.resources -contains 'path_conventions' -and
    $manifest.resources -contains 'prompt_selection_guide' -and
    $manifest.resources -contains 'latest_diagnostics_metrics' -and
    $manifest.resources -contains 'client_usage_guide' -and
    $manifest.resources -contains 'inspector_quickstart' -and
    $manifest.resources -contains 'surface_map'
)

[pscustomobject]@{
    test = 'wechat-mcp-server-inventory'
    pass = $pass
    exit_code = $(if ($pass) { 0 } else { 1 })
    resource_count = @($manifest.resources).Count
    tool_count = @($manifest.tools).Count
    prompt_count = @($manifest.prompts).Count
    has_inventory_resource = ($manifest.resources -contains 'server_inventory')
    has_usage_resource = ($manifest.resources -contains 'client_usage_guide')
    has_consumer_router_resource = ($manifest.resources -contains 'consumer_router')
    has_path_conventions_resource = ($manifest.resources -contains 'path_conventions')
    has_prompt_selection_guide_resource = ($manifest.resources -contains 'prompt_selection_guide')
    has_inspector_quickstart_resource = ($manifest.resources -contains 'inspector_quickstart')
    has_surface_map_resource = ($manifest.resources -contains 'surface_map')
} | ConvertTo-Json -Depth 5

exit $(if ($pass) { 0 } else { 1 })

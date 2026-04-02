param()

$repoRoot = Split-Path $PSScriptRoot -Parent
$docPath = Join-Path $repoRoot 'MCP_REGISTRY_READINESS.md'
$serverPath = Join-Path $repoRoot 'server.json'

foreach ($path in @($docPath, $serverPath)) {
    if (-not (Test-Path $path)) {
        throw "Missing file: $path"
    }
}

$doc = Get-Content -Path $docPath -Raw -Encoding UTF8
$server = Get-Content -Path $serverPath -Raw -Encoding UTF8 | ConvertFrom-Json

$requiredTokens = @(
    'server.json',
    'mcpName',
    'scripts/wechat-mcp-server.mjs',
    'machine-local',
    'clone-based usage'
)

$missing = @($requiredTokens | Where-Object { $doc -notmatch [regex]::Escape($_) })

$rootedPattern = '[A-Za-z]:\\'
$hasRootedPath = $doc -match $rootedPattern
$hasResource = @($server.resources) -contains 'registry_readiness'

$result = [pscustomobject]@{
    test = 'wechat-mcp-registry-readiness'
    pass = ($missing.Count -eq 0 -and -not $hasRootedPath -and $hasResource)
    missing_tokens = $missing
    rooted_path_found = $hasRootedPath
    server_resource_present = $hasResource
    exit_code = $(if ($missing.Count -eq 0 -and -not $hasRootedPath -and $hasResource) { 0 } else { 1 })
}

$result | ConvertTo-Json -Depth 5
exit $result.exit_code

param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$mcpRoot = Join-Path $repoRoot 'mcp\wechat-devtools-mcp'
$serverScript = Join-Path $mcpRoot 'src\server.ts'
$startScript = Join-Path $mcpRoot 'src\start.ts'
$tsxCli = Join-Path $mcpRoot 'node_modules\tsx\dist\cli.mjs'

Assert-True (Test-Path $mcpRoot) 'mcp root should exist'
Assert-True (Test-Path $serverScript) 'server.ts should exist'
Assert-True (Test-Path $startScript) 'start.ts should exist'

Push-Location $mcpRoot
npm run check | Out-Null
$checkCode = $LASTEXITCODE
Pop-Location
Assert-Equal $checkCode 0 'mcp TypeScript should pass npm run check'

Assert-True (Test-Path $tsxCli) 'tsx cli should exist'
$startOutput = & node $tsxCli $startScript 2>&1 | Out-String
Assert-Equal $LASTEXITCODE 0 'readonly mcp stdio start should exit cleanly'
Assert-True ($startOutput -match 'FastMCP warning' -or [string]::IsNullOrWhiteSpace($startOutput)) 'mcp start output should be expected warning or empty'

New-TestResult -Name 'mcp-readonly' -Data @{
    pass      = $true
    exit_code = 0
    started   = $true
}

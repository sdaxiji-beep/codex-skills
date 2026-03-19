param([hashtable]$FlowResult, [hashtable]$Context)

. "$PSScriptRoot\test-common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$docPath = Join-Path $repoRoot 'mcp\wechat-devtools-mcp\OPERATIONS.md'
Assert-True (Test-Path $docPath) "OPERATIONS.md should exist for readonly MCP v1"

$content = Get-Content $docPath -Raw
Assert-True ($content -match "readonly-only") "OPERATIONS.md should declare readonly-only scope"
Assert-True ($content -match "Invoke-WechatReadonlyCheck") "OPERATIONS.md should include readonly check command"
Assert-True ($content -match "Failure Triage") "OPERATIONS.md should include failure triage section"

New-TestResult -Name 'mcp-readonly-operations-doc' -Data @{
    pass = $true
    exit_code = 0
    path = $docPath
}

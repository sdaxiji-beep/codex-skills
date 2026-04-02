param([hashtable]$FlowResult, [hashtable]$Context)
. "$PSScriptRoot\test-common.ps1"

$repoRoot = Split-Path $PSScriptRoot -Parent
$entry = Join-Path $repoRoot 'mcp\wechat-devtools-mcp-write\node_modules\tsx\dist\cli.mjs'
$serverPath = Join-Path $repoRoot 'mcp\wechat-devtools-mcp-write\src\server.ts'
$auditPath = Join-Path $repoRoot 'artifacts\mcp-write-preview-audit.jsonl'

Assert-True (Test-Path $entry) "tsx entry should exist"
Assert-True (Test-Path $serverPath) "server.ts should exist"

$beforeCount = 0
if (Test-Path $auditPath) {
    $beforeCount = @((Get-Content $auditPath -ErrorAction SilentlyContinue)).Count
}

$nodeCode = @"
import { recordPreviewProjectAudit } from '$($serverPath.Replace('\','/'))';
const logPath = recordPreviewProjectAudit({
  status: 'audit_test',
  executeRequested: true,
  hasConfirmationPayload: true
});
console.log(JSON.stringify({ logPath }));
"@

$raw = & node $entry -e $nodeCode 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -and $raw -match 'spawn EPERM') {
    New-TestResult -Name 'mcp-write-preview-audit' -Data @{
        pass = $true
        exit_code = 0
        skipped = $true
        reason = 'environment_spawn_eperm'
    }
    return
}
try {
    $json = $raw | ConvertFrom-Json
}
catch {
    throw "audit append parse failed: $raw"
}

Assert-True (Test-Path $auditPath) "audit log should exist"
$afterLines = @(Get-Content $auditPath -ErrorAction SilentlyContinue)
$afterCount = $afterLines.Count
Assert-True ($afterCount -gt $beforeCount) "audit line count should increase"

$lastLine = $afterLines | Select-Object -Last 1
$lastJson = $lastLine | ConvertFrom-Json
Assert-Equal $lastJson.tool 'preview_project' 'audit tool should be preview_project'
Assert-Equal $lastJson.status 'audit_test' 'audit status should match'

New-TestResult -Name 'mcp-write-preview-audit' -Data @{
    pass = $true
    exit_code = 0
    before_count = $beforeCount
    after_count = $afterCount
    audit_path = $auditPath
}
